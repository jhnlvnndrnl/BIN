import os
import json
import httpx
from fastapi import FastAPI, HTTPException, Depends, Header
from pydantic import BaseModel
from typing import Optional
import firebase_admin
from firebase_admin import credentials, auth

# Load Firebase from ENV ONLY (safe for Railway)
service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT")

if not service_account_json:
    raise Exception("FIREBASE_SERVICE_ACCOUNT is not set")

cred = credentials.Certificate(json.loads(service_account_json))
firebase_admin.initialize_app(cred)

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    raise Exception("Supabase ENV variables missing")

app = FastAPI(title="BIN Backend")

# ─────────────────────────────────────────────
# Verify Firebase Token
# ─────────────────────────────────────────────
async def get_current_user(authorization: Optional[str] = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Authorization header")

    token = authorization.split(" ")[1]

    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Token expired")
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")


# ─────────────────────────────────────────────
# Models
# ─────────────────────────────────────────────
class UserProfile(BaseModel):
    display_name: Optional[str] = None


# ─────────────────────────────────────────────
# UPSERT PROFILE
# ─────────────────────────────────────────────
@app.post("/profile")
async def upsert_profile(
    profile: UserProfile = UserProfile(),
    user=Depends(get_current_user)
):
    uid = user["uid"]
    phone = user.get("phone_number")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{SUPABASE_URL}/rest/v1/profiles",
            headers={
                "apikey": SUPABASE_SERVICE_KEY,
                "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
                "Content-Type": "application/json",
                "Prefer": "resolution=merge-duplicates"
            },
            json={
                "id": uid,
                "phone": phone,
                "display_name": profile.display_name
            }
        )

    if response.status_code not in (200, 201):
        raise HTTPException(
            status_code=500,
            detail=f"Supabase error: {response.text}"
        )

    return {"status": "success", "uid": uid}


# ─────────────────────────────────────────────
# GET PROFILE (CHECK IF USER EXISTS)
# ─────────────────────────────────────────────
@app.get("/profile")
async def get_profile(user=Depends(get_current_user)):
    uid = user["uid"]

    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{SUPABASE_URL}/rest/v1/profiles?id=eq.{uid}",
            headers={
                "apikey": SUPABASE_SERVICE_KEY,
                "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
            }
        )

    data = response.json()

    if not data:
        raise HTTPException(status_code=404, detail="Profile not found")

    return data[0]


# ─────────────────────────────────────────────
# Health Check
# ─────────────────────────────────────────────
@app.get("/")
def health_check():
    return {"status": "BIN Backend is running"}