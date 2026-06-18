# App Review Notes Draft

LocalDictate is a local-first macOS dictation utility.

The app uses:

- Microphone permission to record the user's spoken dictation.
- Speech Recognition permission to transcribe the user's speech.
- Accessibility permission only to paste the user's dictated text into the currently focused editable text field after recording.

Accessibility is not used to read arbitrary screen contents or automate unrelated workflows. If no editable text field is focused, LocalDictate keeps the generated text available inside the app so the user can copy it manually.

V1 does not require an account and does not send audio, transcripts, cleanup text, history, diagnostics, or analytics to a server. Dictation history is stored locally on the user's Mac.

Suggested reviewer flow:

1. Launch LocalDictate.
2. Press Command-D or click the menu bar item to start dictation.
3. Grant Microphone and Speech Recognition permissions if prompted.
4. Grant Accessibility if testing auto-paste.
5. Focus a text field in another app.
6. Press Command-D, speak, then press Command-D again to stop.
7. Confirm the generated text appears in the focused text field.
