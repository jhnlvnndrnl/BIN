# main.py
import os
import json
import httpx
from fastapi import FastAPI, HTTPException, Depends, Header
from pydantic import BaseModel
from typing import Optional
import firebase_admin
from firebase_admin import credentials, auth
from dotenv import load_dotenv
import logging

logger = logging.getLogger(__name__)

# -----------------------------
# Load environment variables
# -----------------------------
load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
FIREBASE_SERVICE_ACCOUNT = os.getenv("FIREBASE_SERVICE_ACCOUNT", "./serviceAccountKey.json")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    raise Exception("Supabase ENV variables missing")

# -----------------------------
# Initialize Firebase
# -----------------------------
if FIREBASE_SERVICE_ACCOUNT.strip().startswith("{"):
    cred = credentials.Certificate(json.loads(FIREBASE_SERVICE_ACCOUNT))
else:
    if not os.path.isfile(FIREBASE_SERVICE_ACCOUNT):
        raise Exception(f"Firebase service account file not found at {FIREBASE_SERVICE_ACCOUNT}")
    cred = credentials.Certificate(FIREBASE_SERVICE_ACCOUNT)

if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)

# -----------------------------
# FastAPI app
# -----------------------------
app = FastAPI(title="BIN Backend")

# -----------------------------
# Pydantic models
# -----------------------------
class UserProfile(BaseModel):
    full_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    role: Optional[str] = "resident"

# -----------------------------
# Firebase Auth Dependency
# -----------------------------
async def get_current_user(authorization: Optional[str] = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Authorization header")
    token = authorization.split(" ")[1]

    try:
        return auth.verify_id_token(token)
    except auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Token expired")
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")

# -----------------------------
# Supabase helper
# -----------------------------
async def supabase_request(method: str, path: str, json_data=None, extra_headers=None):
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
    }
    if extra_headers:
        headers.update(extra_headers)

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            if method.lower() == "get":
                response = await client.get(url, headers=headers)
            elif method.lower() == "post":
                response = await client.post(url, headers=headers, json=json_data)
            else:
                raise ValueError(f"Unsupported method: {method}")

            if response.status_code not in (200, 201, 404):
                logger.warning("Supabase %s ERROR %d: %s", method, response.status_code, response.text)
                response.raise_for_status()

            return response.json()
        except httpx.HTTPStatusError as e:
            logger.warning("Supabase %s ERROR %d: %s", method, e.response.status_code, e.response.text)
            raise HTTPException(status_code=e.response.status_code, detail=e.response.text)
        except httpx.RequestError as e:
            logger.error("Supabase %s network failure: %s", method, e)
            raise HTTPException(status_code=502, detail="Supabase network error")

# -----------------------------
# Health check
# -----------------------------
@app.get("/")
def health_check():
    return {"status": "BIN Backend is running"}

# -----------------------------
# Get Profile
# -----------------------------
@app.get("/profile")
async def get_profile(user=Depends(get_current_user)):
    uid = user.get("uid")
    if not uid:
        raise HTTPException(status_code=400, detail="User UID not found")

    data = await supabase_request("get", f"profiles?id=eq.{uid}")
    if not data:
        raise HTTPException(status_code=404, detail="Profile not found")
    return data[0]

# -----------------------------
# Upsert Profile
# -----------------------------
@app.post("/profile")
async def upsert_profile(profile: UserProfile = UserProfile(), user=Depends(get_current_user)):
    uid = user.get("uid")
    phone = user.get("phone_number")

    if not uid:
        raise HTTPException(status_code=400, detail="User UID not found in token")

    payload = {
        "id": uid,
        "full_name": profile.full_name,
        "phone": phone,
        "role": profile.role or "resident"
    }

    data = await supabase_request(
        "post",
        "profiles",
        json_data=payload,
        extra_headers={"Prefer": "resolution=merge-duplicates"}
    )

    return {"status": "success", "uid": uid}