import io
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from fastapi import APIRouter, HTTPException, Query, BackgroundTasks
from fastapi.responses import StreamingResponse
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib import colors

from database import get_db
from models import AttendanceRecord

router = APIRouter(tags=["Attendance"])

# Gmail Credentials Configuration
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
SENDER_EMAIL = "ibrahimekomu35@gmail.com"        # Replace with your Gmail address
SENDER_PASSWORD = "rgwq tskd jqug lbxk"          # Replace with your 16-character App Password


def send_parent_email(to_email: str, student_name: str, status: str, date: str):
    """Helper function to send email notification to parents."""
    try:
        if not to_email:
            return

        msg = MIMEMultipart()
        msg['From'] = SENDER_EMAIL
        msg['To'] = to_email
        msg['Subject'] = f"Attendance Alert: {student_name}"

        body = (
            f"Dear Parent,\n\n"
            f"Please be informed that {student_name} was marked '{status}' on {date}.\n\n"
            f"Regards,\n"
            f"School Administration"
        )
        msg.attach(MIMEText(body, 'plain'))

        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        server.login(SENDER_EMAIL, SENDER_PASSWORD)
        server.send_message(msg)
        server.quit()
        print(f"Email sent successfully to {to_email}")
    except Exception as e:
        print(f"Failed to send email: {e}")


@router.get("/attendance")
def get_attendance(date: str = Query(...), course_id: int = Query(...), search: str = Query("", alias="search")):
    db = get_db()
    try:
        cursor = db.cursor(dictionary=True)
        query = """
            SELECT 
                s.student_id AS id,
                CONCAT(s.first_name, ' ', s.last_name) AS name,
                s.admission_number,
                COALESCE(a.status, 'Not Marked') AS status
            FROM students s
            LEFT JOIN attendance a 
                ON s.student_id = a.student_id AND a.date = %s AND a.course_id = %s
            WHERE (s.course_id = %s OR %s = 0)
              AND (LOWER(CONCAT(s.first_name, ' ', s.last_name)) LIKE %s 
                   OR LOWER(s.admission_number) LIKE %s)
        """
        search_pattern = f"%{search.lower()}%"
        cursor.execute(query, (date, course_id, course_id, course_id, search_pattern, search_pattern))
        records = cursor.fetchall()
        return records
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.post("/attendance")
def record_attendance(data: AttendanceRecord, background_tasks: BackgroundTasks):
    db = get_db()
    try:
        cursor = db.cursor(dictionary=True)

        # 1. Upsert attendance record
        upsert_query = """
            INSERT INTO attendance (student_id, course_id, status, date) 
            VALUES (%s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE status = VALUES(status)
        """
        cursor.execute(upsert_query, (data.student_id, data.course_id, data.status, data.date))

        # 2. Trigger parent email notification if marked Absent
        if data.status == 'Absent':
            parent_query = """
                SELECT p.parent_id, p.email, 
                       CONCAT(p.first_name, ' ', p.last_name) AS parent_name,
                       CONCAT(s.first_name, ' ', s.last_name) AS student_name
                FROM student_parents sp
                JOIN parents p ON sp.parent_id = p.parent_id
                JOIN students s ON sp.student_id = s.student_id
                WHERE sp.student_id = %s
                ORDER BY sp.is_primary_contact DESC
                LIMIT 1
            """
            cursor.execute(parent_query, (data.student_id,))
            parent_info = cursor.fetchone()

            if parent_info:
                email_body = f"Alert: {parent_info['student_name']} was marked ABSENT on {data.date}."
                
                # Log notification in system database
                notif_query = """
                    INSERT INTO notifications (student_id, parent_id, notification_type, message, delivery_status)
                    VALUES (%s, %s, 'Absent Email Alert', %s, 'Sent')
                """
                cursor.execute(notif_query, (data.student_id, parent_info['parent_id'], email_body))

                # Queue background task to send the email
                if parent_info.get('email'):
                    background_tasks.add_task(
                        send_parent_email, 
                        parent_info['email'], 
                        parent_info['student_name'], 
                        data.status, 
                        data.date
                    )

        db.commit()
        return {"message": "Attendance updated successfully"}
    except Exception as e:
        db.rollback()
        print("ERROR IN RECORD ATTENDANCE:", str(e))
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.get("/attendance/student-history/{student_id}")
def get_student_history(student_id: int):
    db = get_db()
    try:
        cursor = db.cursor(dictionary=True)
        query = """
            SELECT a.date, a.status, c.course_code, c.course_name
            FROM attendance a
            JOIN courses c ON a.course_id = c.course_id
            WHERE a.student_id = %s
            ORDER BY a.date DESC
        """
        cursor.execute(query, (student_id,))
        records = cursor.fetchall()
        return records
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.get("/notifications")
def get_notifications():
    db = get_db()
    try:
        cursor = db.cursor(dictionary=True)
        query = """
            SELECT n.notification_id, CONCAT(s.first_name, ' ', s.last_name) AS student_name,
                   CONCAT(p.first_name, ' ', p.last_name) AS parent_name, p.phone,
                   n.notification_type, n.message, n.sent_at, n.delivery_status
            FROM notifications n
            JOIN students s ON n.student_id = s.student_id
            JOIN parents p ON n.parent_id = p.parent_id
            ORDER BY n.sent_at DESC
        """
        cursor.execute(query)
        logs = cursor.fetchall()
        return logs
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.get("/attendance/pdf")
def export_attendance_pdf(date: str = Query(...), course_id: int = Query(101), status_filter: str = Query("All")):
    db = get_db()
    try:
        cursor = db.cursor(dictionary=True)
        query = """
            SELECT 
                s.student_id AS id,
                CONCAT(s.first_name, ' ', s.last_name) AS name,
                s.admission_number,
                COALESCE(a.status, 'Not Marked') AS status
            FROM students s
            LEFT JOIN attendance a 
                ON s.student_id = a.student_id AND a.date = %s AND a.course_id = %s
            WHERE (s.course_id = %s OR %s = 0)
        """
        cursor.execute(query, (date, course_id, course_id, course_id))
        all_records = cursor.fetchall()

        total = len(all_records)
        present_count = sum(1 for r in all_records if r['status'] == 'Present')
        absent_count = sum(1 for r in all_records if r['status'] == 'Absent')
        late_count = sum(1 for r in all_records if r['status'] == 'Late')
        excused_count = sum(1 for r in all_records if r['status'] == 'Excused')

        if status_filter != "All":
            filtered_records = [r for r in all_records if r['status'] == status_filter]
        else:
            filtered_records = all_records

        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=letter)
        elements = []
        styles = getSampleStyleSheet()

        elements.append(Paragraph("<b>Student Attendance Report</b>", styles['Title']))
        elements.append(Paragraph(f"<b>Date:</b> {date} | <b>Filter:</b> {status_filter}", styles['Normal']))
        elements.append(Spacer(1, 10))

        summary_data = [
            ["Total", "Present", "Absent", "Late", "Excused"],
            [str(total), str(present_count), str(absent_count), str(late_count), str(excused_count)]
        ]
        summary_table = Table(summary_data, colWidths=[90, 90, 90, 90, 90])
        summary_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#F0F4F8')),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.lightgrey),
        ]))
        elements.append(summary_table)
        elements.append(Spacer(1, 15))

        table_data = [["ID", "Name", "Admission No.", "Status"]]
        for row in filtered_records:
            table_data.append([
                str(row['id']),
                row['name'],
                str(row['admission_number']),
                row['status']
            ])

        pdf_table = Table(table_data, colWidths=[50, 200, 130, 100])
        pdf_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1E88E5')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.lightgrey),
        ]))

        elements.append(pdf_table)
        doc.build(elements)
        buffer.seek(0)

        return StreamingResponse(
            buffer,
            media_type="application/pdf",
            headers={"Content-Disposition": f"attachment; filename=attendance_{date}_{status_filter}.pdf"}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()