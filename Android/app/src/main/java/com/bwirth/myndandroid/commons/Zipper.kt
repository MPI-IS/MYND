package com.bwirth.myndandroid.commons

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.support.v4.content.FileProvider
import android.util.Log
import android.widget.Toast
import com.bwirth.myndandroid.BuildConfig
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

fun compressFiles(c: Context, filePathList: List<File>, outputPath: File) {
    if (!outputPath.parentFile.exists()) {
        if (!outputPath.parentFile.mkdirs()) {
            throw Exception("Could not create directory ${outputPath.parent}")
        }
    }

    var origin: BufferedInputStream
    val out = ZipOutputStream(BufferedOutputStream(outputPath.outputStream()))

    val data = ByteArray(2048)

    for (i in 0 until filePathList.size) {
        val fi = filePathList[i].inputStream()
        origin = BufferedInputStream(fi, 2048)
        val entry = ZipEntry(filePathList[i].absolutePath.substring(filePathList[i].absolutePath.lastIndexOf("/") + 1))
        out.putNextEntry(entry)
        var count: Int
        count = origin.read(data, 0, 2048)
        while (count != -1) {
            out.write(data, 0, count)
            count = origin.read(data, 0, 2048)
        }
        origin.close()
    }
    out.close()
    Log.i("Zipper", "Zipped file to destination $outputPath")
}

