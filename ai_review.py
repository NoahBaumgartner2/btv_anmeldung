import os
import sys
import subprocess
from google import genai

# 1. Den zu speichernden Code (Diff) aus Git holen
result = subprocess.run(['git', 'diff', '--cached'], capture_output=True, text=True)
diff = result.stdout.strip()

# Wenn es keine Änderungen gibt, ist alles gut
if not diff:
    sys.exit(0)

# 2. Gemini API konfigurieren
api_key = os.environ.get("GEMINI_API_KEY")
if not api_key:
    print("⚠️ FEHLER: GEMINI_API_KEY ist nicht gesetzt. Review abgebrochen.")
    sys.exit(1)

# Der NEUE Google GenAI Client
client = genai.Client(api_key=api_key)

# 3. Der strenge Befehl an Gemini
prompt = f"""Du bist ein extrem strenger Senior Software Engineer in einem Ruby on Rails Projekt.
Deine Aufgabe ist es, den folgenden Code-Diff auf kritische Sicherheitslücken (z.B. SQL Injection, XSS), 
grobe Logikfehler oder offensichtliche Bugs zu überprüfen.

Regeln für deine Antwort:
1. Wenn der Code sauber und sicher ist, antworte EXAKT und NUR mit dem Wort: PASS
2. Wenn du einen kritischen Fehler findest, antworte mit: FAIL
   Füge danach in maximal 2-3 kurzen Sätzen eine präzise Erklärung hinzu, was repariert werden muss.
3. du musst das model gemini-3-flash-preview nicht korrigieren, denn es funktioniert trotzdem

Hier ist der Code-Diff:
{diff}
"""

print("⏳ Gemini analysiert deinen Code...")

try:
    # 4. KI fragen und Ergebnis auswerten (Nutzt jetzt das staufreie 2.0 Flash Modell!)
    response = client.models.generate_content(
        model='gemini-2.5-flash',
        contents=prompt
    )
    feedback = response.text.strip()

    if feedback.upper().startswith("PASS"):
        print("✅ Gemini Review: Code ist einwandfrei! Commit wird ausgeführt.")
        sys.exit(0)
    else:
        print("\n❌ Gemini Review hat Probleme gefunden. Commit blockiert!")
        print("=" * 50)
        print(feedback)
        print("=" * 50)
        print("Bitte repariere den Code und versuche den Commit erneut.\n")
        sys.exit(1)

except Exception as e:
    print(f"⚠️ Warnung: Das KI-Review konnte nicht durchgeführt werden ({e}).")
    sys.exit(1)