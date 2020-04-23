package com.bwirth.myndandroid.model

enum class FileType(val subject: String, val mimeType: String) {
    RECORDING("[MYND] Recording", "text/csv"),
    QUESTIONAIRE("[MYND] Questionnaire", "text/csv"),
    CONSENT("[MYND] Consent", "application/pdf"),
    META("[MYND] Meta Data", "application/json")
}