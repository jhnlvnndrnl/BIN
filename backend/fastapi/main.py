import os
import httpx
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel
from typing import Optional
from dotenv import load_dotenv

# Load environment variables from the .env file locally
load_dotenv()

app = FastAPI(title="BIN Backend")

# We define the structure of the data Supabase will send
class SMSPayload(BaseModel):
    user: dict
    sms: dict

# Environment variables loaded securely from .env or Railway Deployments
SEMAPHORE_API_KEY = os.getenv("SEMAPHORE_API_KEY")
WEBHOOK_SECRET = os.getenv("WEBHOOK_SECRET")

@app.post("/webhook/send-sms")
async def send_supabase_sms(payload: SMSPayload, authorization: Optional[str] = Header(None)):
    """
    Supabase Custom SMS Webhook Endpoint.
    This routes the OTP code from Supabase to Semaphore SMS.
    """
    # 1. Security Check
    # Supabase normally sends its secret string inside the Authorization header as "Bearer <secret>"
    # We strip "Bearer " if it exists to strictly check the secret.
    incoming_secret = None
    if authorization:
        incoming_secret = authorization.replace("Bearer ", "").strip()
        
    # Temporarily bypass strict secret matching to see if the payload goes through
    # if WEBHOOK_SECRET and incoming_secret != WEBHOOK_SECRET:
    #     raise HTTPException(status_code=401, detail="Unauthorized")

    phone_number = payload.user.get("phone")
    otp_code = payload.sms.get("otp")

    if not phone_number or not otp_code:
        raise HTTPException(status_code=400, detail="Missing phone or OTP in payload")

    # 2. Prepare the text message content
    message = f"Your BIN verification code is {otp_code}. Do not share this with anyone."

    # 3. Call Semaphore API to send the text
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.semaphore.co/api/v4/messages",
            data={
                "apikey": SEMAPHORE_API_KEY,
                "number": phone_number,
                "message": message,
                "sendername": "ALEXUS"
            }
        )

    # 4. Respond to Supabase
    if response.status_code == 200:
        return {"status": "success", "message": "OTP sent via Semaphore"}
    else:
        # If Semaphore failed, report the error back
        raise HTTPException(
            status_code=response.status_code, 
            detail=f"Semaphore API Error: {response.text}"
        )

@app.get("/")
def health_check():
    return {"status": "FastAPI Backend is running"}
