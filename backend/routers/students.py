from fastapi import APIRouter, HTTPException
from database import get_db
from models import NewStudent

router = APIRouter(tags=["Students"])

@router.post("/students")
def add_student(student: NewStudent):
    try:
        db = get_db()
        cursor = db.cursor()
        
        # 1. Insert Student
        query_student = """
            INSERT INTO students (first_name, last_name, admission_number, course_id, school_id) 
            VALUES (%s, %s, %s, %s, %s)
        """
        cursor.execute(query_student, (student.first_name, student.last_name, student.admission_number, student.course_id, 1))
        new_student_id = cursor.lastrowid

        # 2. Insert Parent and Link if parent details are provided
        if student.parent:
            query_parent = """
                INSERT INTO parents (first_name, last_name, phone, relationship)
                VALUES (%s, %s, %s, %s)
            """
            cursor.execute(query_parent, (student.parent.first_name, student.parent.last_name, student.parent.phone, student.parent.relationship))
            new_parent_id = cursor.lastrowid

            query_link = """
                INSERT INTO student_parents (student_id, parent_id, is_primary_contact)
                VALUES (%s, %s, TRUE)
            """
            cursor.execute(query_link, (new_student_id, new_parent_id))

        db.commit()
        cursor.close()
        db.close()
        return {"message": "Student added successfully", "student_id": new_student_id}
    except Exception as e:
        print("DATABASE ERROR ADDING STUDENT:", str(e))
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/students/{student_id}")
def update_student(student_id: int, student: NewStudent):
    try:
        db = get_db()
        cursor = db.cursor()
        query = """
            UPDATE students 
            SET first_name = %s, last_name = %s, admission_number = %s, course_id = %s
            WHERE student_id = %s
        """
        cursor.execute(query, (student.first_name, student.last_name, student.admission_number, student.course_id, student_id))
        db.commit()
        cursor.close()
        db.close()
        return {"message": "Student updated successfully"}
    except Exception as e:
        print("DATABASE ERROR UPDATING STUDENT:", str(e))
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/students/{student_id}")
def delete_student(student_id: int):
    try:
        db = get_db()
        cursor = db.cursor()
        cursor.execute("DELETE FROM attendance WHERE student_id = %s", (student_id,))
        cursor.execute("DELETE FROM student_parents WHERE student_id = %s", (student_id,))
        cursor.execute("DELETE FROM students WHERE student_id = %s", (student_id,))
        db.commit()
        cursor.close()
        db.close()
        return {"message": "Student deleted successfully"}
    except Exception as e:
        print("DATABASE ERROR DELETING STUDENT:", str(e))
        raise HTTPException(status_code=500, detail=str(e))