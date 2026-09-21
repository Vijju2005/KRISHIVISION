import os, sys
os.environ["JWT_SECRET_KEY"] = "dev-secret-key-123456789"
sys.path.append(r"c:\Users\keert\Downloads\Krishi222-fixed\krishivision_ai\backend")

from app.database import SessionLocal
from app.models.orm_models import APYCropStatistic, District, State
from sqlalchemy import func

db = SessionLocal()

print("=== APY DISTINCT STATES ===")
states = db.query(APYCropStatistic.state_name).distinct().all()
print([s[0] for s in states[:10]])

print("\n=== APY DISTRICT FOR BETUL ===")
betul_records = db.query(APYCropStatistic.state_name, APYCropStatistic.district_name).filter(
    func.lower(APYCropStatistic.district_name).like("%betul%")
).distinct().all()
print(betul_records)

db.close()
