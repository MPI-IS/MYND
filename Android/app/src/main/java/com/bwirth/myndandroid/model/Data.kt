package com.bwirth.myndandroid.model

import java.util.*

class Data(val type: FileType, val date: Date, val session: Int, val uuid: String, val runid: String, val fileName: String) {
    var stored = true
    var transmitted = false
}