from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import courses, students, attendance

app = FastAPI(title="Attendance Monitoring System API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
@app.get("/")
def root():
    return {"status": "ok", "message": "Attendance Monitoring System API is running"}

app.include_router(courses.router)
app.include_router(students.router)
app.include_router(attendance.router)