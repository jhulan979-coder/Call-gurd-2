package com.example.call_guard

object CallAdvice {
    fun text(score: Int): String {
        if (score >= 65) {
            return "Salah: Reject karo\nOTP, PIN, CVV ya bank detail kabhi na batayein."
        }
        if (score >= 35) {
            return "Salah: Savdhani se uthao\nOTP, KYC ya bank ki baat ho to turant kaat do."
        }
        return "Salah: Uthao\nPar personal jaankari tab tak mat do jab tak pehchaan na ho."
    }
}
