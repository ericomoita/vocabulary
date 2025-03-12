package com.example.vocabulary_memorizer

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.widget.RemoteViews
import java.io.File

class MyWidgetProvider : AppWidgetProvider() {

    companion object {
        /**
         * Retrieve a random word from the database.
         * If an error occurs, it returns a default pair.
         */
        fun getRandomWord(context: Context): Pair<String, String> {
            return try {
                // Construct the database file path (adjust if needed)
                val dbFile = File(context.filesDir, "words.db")
                if (!dbFile.exists()) {
                    return Pair("No word", "No translation")
                }
                val dbPath = dbFile.absolutePath
                // Open the database in read-only mode
                val database = SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READONLY)
                var result = Pair("No word", "No translation")
                // Query to select a random word from the "words" table
                val cursor = database.rawQuery("SELECT * FROM words ORDER BY RANDOM() LIMIT 1", null)
                if (cursor.moveToFirst()) {
                    // Get the indices for the columns "word" and "translation"
                    val wordIndex = cursor.getColumnIndex("word")
                    val translationIndex = cursor.getColumnIndex("translation")
                    if (wordIndex != -1 && translationIndex != -1) {
                        val word = cursor.getString(wordIndex)
                        val translation = cursor.getString(translationIndex)
                        result = Pair(word, translation)
                    }
                }
                cursor.close()
                database.close()
                result
            } catch (e: Exception) {
                // Log the exception if needed
                e.printStackTrace()
                Pair("Error", "Error")
            }
        }

        /**
         * Update the widget with a random word.
         */
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val randomPair = getRandomWord(context)
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            views.setTextViewText(R.id.tvWord, randomPair.first)
            views.setTextViewText(R.id.tvTranslation, randomPair.second)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        // Update each widget instance
        for (widgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, widgetId)
        }
    }
}
