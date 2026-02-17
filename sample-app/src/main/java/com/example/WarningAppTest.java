package com.example;

import java.util.ArrayList;
import java.util.List;

/**
 * Console test harness with intentional bugs for JDB debugging.
 *
 * Bugs:
 * 1. NullPointerException  processMessage returns null for empty input
 * 2. Off-by-one error  counter displays warningCount - 1
 * 3. NullPointerException  clearHistory sets warningHistory = null instead of clear()
 * 4. StringIndexOutOfBoundsException  substring(0, 3) without bounds check
 */
public class WarningAppTest {

    private List<String> warningHistory;
    private int warningCount;

    public WarningAppTest() {
        warningHistory = new ArrayList<>();
        warningCount = 0;
    }

    private String processMessage(String message) {
        // BUG 1: This will throw NPE if message is null
        String trimmed = message.trim();

        if (trimmed.isEmpty()) {
            // BUG 1 continued: returns null instead of a default message
            return null;
        }

        return "WARNING: " + trimmed.toUpperCase();
    }

    private void showWarning(String text) {
        // BUG 1: No null/empty check  processMessage may return null
        String processed = processMessage(text);

        // BUG 4: Substring without bounds check  crashes if input < 3 chars
        String preview = text.substring(0, 3);
        System.out.println("Preview: " + preview);

        // BUG 3 surface: NPE if warningHistory was set to null by clearHistory
        warningHistory.add(processed);
        warningCount++;

        // BUG 2: Off-by-one  displays count - 1 instead of count
        System.out.println("Warnings shown: " + (warningCount - 1));

        System.out.println("Warning #" + warningCount + ": " + processed);
    }

    private void clearHistory() {
        // BUG 3: Sets list to null instead of clearing it  next add() will NPE
        warningHistory = null;
        warningCount = 0;
        System.out.println("History cleared (or is it?)");
    }

    public static void main(String[] args) {
        WarningAppTest app = new WarningAppTest();

        // Scenario 1: Normal input  works but shows BUG 2 (off-by-one)
        System.out.println("=== Scenario 1: Normal input ===");
        app.showWarning("Hello World");

        // Scenario 2: Empty input  triggers BUG 4 (StringIndexOutOfBounds) first,
        // which masks BUG 1 (processMessage returns null)
        System.out.println("\n=== Scenario 2: Empty input (BUG 4 + BUG 1) ===");
        try {
            app.showWarning("");
        } catch (Exception e) {
            System.out.println("CAUGHT: " + e);
        }

        // Scenario 3: Short input  triggers BUG 4 (StringIndexOutOfBounds)
        System.out.println("\n=== Scenario 3: Short input (BUG 4) ===");
        try {
            app.showWarning("Hi");
        } catch (Exception e) {
            System.out.println("CAUGHT: " + e);
        }

        // Scenario 4: Clear then show  triggers BUG 3 (NPE on warningHistory)
        System.out.println("\n=== Scenario 4: Clear then show (BUG 3) ===");
        app.clearHistory();
        try {
            app.showWarning("After clear");
        } catch (Exception e) {
            System.out.println("CAUGHT: " + e);
        }

        // Scenario 5: Null input  triggers BUG 1 (NPE on message.trim())
        System.out.println("\n=== Scenario 5: Null input (BUG 1) ===");
        app = new WarningAppTest(); // fresh instance
        try {
            app.showWarning(null);
        } catch (Exception e) {
            System.out.println("CAUGHT: " + e);
        }

        System.out.println("\n=== Done ===");
    }
}