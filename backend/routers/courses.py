from fastapi import APIRouter, HTTPException
from database import get_db
from models import NewCourse

router = APIRouter(tags=["Courses"])

@router.get("/courses")
def get_courses():
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT course_id, course_code, course_name FROM courses")
        courses = cursor.fetchall()
        db.close()
        return courses
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/courses")
def add_course(course: NewCourse):
    try:
        db = get_db()
        cursor = db.cursor()
        query = "INSERT INTO courses (course_code, course_name) VALUES (%s, %s)"
        cursor.execute(query, (course.course_code, course.course_name))
        db.commit()
        new_id = cursor.lastrowid
        cursor.close()
        db.close()
        return {"message": "Course added successfully", "course_id": new_id}
    except Exception as e:
        print("DATABASE ERROR ADDING COURSE:", str(e))
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/courses/{course_id}")
def update_course(course_id: int, course: NewCourse):
    try:
        db = get_db()
        cursor = db.cursor()
        query = "UPDATE courses SET course_code = %s, course_name = %s WHERE course_id = %s"
        cursor.execute(query, (course.course_code, course.course_name, course_id))
        db.commit()
        cursor.close()
        db.close()
        return {"message": "Course updated successfully"}
    except Exception as e:
        print("DATABASE ERROR UPDATING COURSE:", str(e))
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/courses/{course_id}")
def delete_course(course_id: int):
    try:
        db = get_db()
        cursor = db.cursor()
        # Delete dependent attendance and student records first to ensure foreign key integrity
        cursor.execute("DELETE FROM attendance WHERE course_id = %s", (course_id,))
        cursor.execute("DELETE FROM students WHERE course_id = %s", (course_id,))
        cursor.execute("DELETE FROM courses WHERE course_id = %s", (course_id,))
        db.commit()
        cursor.close()
        db.close()
        return {"message": "Course deleted successfully"}
    except Exception as e:
        print("DATABASE ERROR DELETING COURSE:", str(e))
        raise HTTPException(status_code=500, detail=str(e))