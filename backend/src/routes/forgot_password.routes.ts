import { Router } from "express";
import {
    sendOTP,
    verifyOTP,
    finalizePasswordReset
} from "../controllers/forgot_password.controller";

const router = Router();

// App calls this to start the flow (sends OTP email)
router.post("/forgot", sendOTP);

// App calls this to verify the OTP code
router.post("/verify-otp", verifyOTP);

// App calls this to set the new password after OTP is verified
router.post("/reset", finalizePasswordReset);

export default router;
