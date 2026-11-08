# Support — Family To-Do for E-Paper

*[Polska wersja poniżej](#pomoc)*

Questions, bugs and ideas: **[open an issue on GitHub](https://github.com/marekpiotrowskimp/family-todo-epaper/issues)**.
How to build the display: [README → Building your own](https://github.com/marekpiotrowskimp/family-todo-epaper#building-your-own).

## FAQ

**Do I need the display?**
No. Without it the app is a task list with reminders on your phone. The display adds the shared, always-visible list for the whole family.

**Where do I get the family key?**
Whoever builds the display runs `tools/make-family-key.sh`; it prints a QR code. Scan it with the iPhone Camera app and tap *Open in To-Do*. A family member who already has the key can show the QR code in **Settings → Show QR code for a family member**.

**"The display has a different family key than this app."**
The key in the app does not match the firmware. Enter the key again (Settings → Change key) or, if the key was regenerated, scan the new QR code.

**The app does not sync.**
Sync works only while the app is open and the display is within Bluetooth range (a few metres). Check that Bluetooth is on and allowed for the app (Settings → Privacy & Security → Bluetooth), then tap the sync button.

**Reminders do not appear.**
Allow notifications for the app in iOS Settings → Notifications. Reminders arrive only on the phone of the task's owner.

**My family does not see my note.**
That is by design: notes are private and stay on the phone where you wrote them. Put anything the whole family should see in the task title.

**How do I remove my data?**
Delete the app. See the [privacy policy](PRIVACY.md).

---

# Pomoc

Pytania, błędy i pomysły: **[zgłoś issue na GitHubie](https://github.com/marekpiotrowskimp/family-todo-epaper/issues)**.

**Czy potrzebuję wyświetlacza?**
Nie. Bez niego aplikacja jest listą zadań z przypomnieniami na telefonie. Wyświetlacz dodaje wspólną, zawsze widoczną listę dla całej rodziny.

**Skąd wziąć klucz rodziny?**
Osoba budująca wyświetlacz uruchamia `tools/make-family-key.sh`, który wypisuje kod QR. Zeskanuj go aplikacją Aparat i stuknij *Otwórz*. Domownik, który ma już klucz, pokaże kod QR w **Ustawienia → Pokaż kod QR dla domownika**.

**„Wyświetlacz ma inny klucz rodziny niż ta aplikacja.”**
Klucz w aplikacji nie pasuje do firmware. Wpisz klucz ponownie (Ustawienia → Zmień klucz) albo zeskanuj nowy kod QR, jeśli klucz wygenerowano od nowa.

**Aplikacja się nie synchronizuje.**
Synchronizacja działa, gdy aplikacja jest otwarta, a wyświetlacz jest w zasięgu Bluetooth (kilka metrów). Sprawdź, czy Bluetooth jest włączony i dozwolony dla aplikacji, i stuknij przycisk synchronizacji.

**Domownicy nie widzą mojej notatki.**
Tak ma być: notatki są prywatne i zostają na telefonie, na którym je zapisano. To, co ma zobaczyć cała rodzina, wpisz w tytule zadania.

**Nie przychodzą przypomnienia.**
Zezwól na powiadomienia w Ustawieniach iOS. Przypomnienie przychodzi tylko na telefon właściciela zadania.
