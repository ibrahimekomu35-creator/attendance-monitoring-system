import mysql.connector

def get_db():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="admin123",  # Update to your local MySQL password
        database="attendance_db"
    )