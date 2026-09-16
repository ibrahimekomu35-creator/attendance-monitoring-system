from typing import Optional, Literal
from pydantic import BaseModel

class ParentData(BaseModel):
    first_name: str
    last_name: str
    phone: str
    relationship: str

class NewStudent(BaseModel):
    first_name: str
    last_name: str
    admission_number: str
    course_id: int
    parent: Optional[ParentData] = None

class AttendanceRecord(BaseModel):
    student_id: int
    course_id: int
    status: Literal['Present', 'Absent', 'Late', 'Excused']
    date: str

class NewCourse(BaseModel):
    course_code: str
    course_name: str