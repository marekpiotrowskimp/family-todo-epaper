# Specyfikacja systemu rodzinnych zadań To-Do

**Status:** wymagania wstępne (do przekazania agentowi implementacyjnemu)  
**Data:** 2026-10-29

## 1. Cel projektu

System do zarządzania zadaniami domowymi, obsługiwany przez aplikacje iOS członków rodziny, z możliwością sterowania zadaniami z poziomu ChatGPT oraz wspólnym urządzeniem ESP32-S3 z wyświetlaczem e-paper. Urządzenie ma własną logikę przechowywania, sortowania i wyboru zadań do prezentacji.

## 2. Komponenty

### 2.1 Aplikacja iOS
- Umożliwia tworzenie, przeglądanie, edytowanie, oznaczanie jako wykonane i usuwanie zadań.
- Każde zadanie jest przypisane do konkretnego użytkownika/nadawcy.
- Obsługuje priorytety, terminy wykonania oraz indywidualne przypomnienia.
- Wykrywa urządzenie ESP32-S3 przez BLE i synchronizuje zadania podczas krótkiego połączenia, po czym się rozłącza.
- Nie wymaga konfiguracji adresu IP urządzenia ani wyboru domowej sieci Wi-Fi.
- Przechowuje dane potrzebne do pracy aplikacji i synchronizacji.

### 2.2 Integracja z ChatGPT
- Użytkownik może zarządzać zadaniami z poziomu ChatGPT (co najmniej: dodanie, odczyt, aktualizacja, ukończenie, usunięcie).
- Integracja ma być ograniczona do uprawnionego użytkownika i nie może udostępniać operacji dowolnym osobom w Internecie.
- **Wymaga weryfikacji technicznej:** aplikacja ChatGPT na iOS nie może być z góry traktowana jako klient lokalnego serwera `localhost` innej aplikacji. Sposób integracji (np. zdalny endpoint narzędziowy, App Intents/Siri lub inny oficjalnie wspierany mechanizm) należy potwierdzić przed implementacją. Lokalny serwer HTTP w aplikacji iOS nie jest zaakceptowaną, zweryfikowaną architekturą wtyczki.

### 2.3 Urządzenie ESP32-S3 + e-paper
- Jest współdzielonym urządzeniem dla kilku członków rodziny.
- Udostępnia interfejs komunikacyjny BLE do odbierania i synchronizacji zadań z wielu telefonów.
- Utrzymuje własną listę zadań oraz logikę ich selekcji i sortowania.
- Wyświetla aktualne zadania na e-paperze.
- Powinno działać bez zależności od konkretnej sieci Wi-Fi.

## 3. Model zadania

Minimalne pola:
- `id` — unikalny identyfikator zadania;
- `ownerId` — identyfikator osoby dodającej zadanie;
- `title` — treść/tytuł zadania;
- `priority` — priorytet;
- `dueDate` — opcjonalny termin wykonania;
- `status` — np. aktywne / ukończone;
- `reminderAt` — opcjonalna data i godzina przypomnienia;
- `updatedAt` — czas ostatniej zmiany, do synchronizacji.

Dodatkowe pola i ich formaty zostaną ustalone na etapie projektowania kontraktów danych.

## 4. Reguły wyświetlania na e-paperze

1. Urządzenie bierze pod uwagę aktywne zadania otrzymane od wszystkich użytkowników.
2. Zadania są porządkowane najpierw według priorytetu (wyższy jako pierwszy), następnie według terminu wykonania (wcześniejszy jako pierwszy).
3. **Co najmniej jedno aktywne zadanie każdego użytkownika, który ma zadania, powinno być widoczne** na ekranie.
4. Pozostałe dostępne miejsca na ekranie wypełniane są zadaniami zgodnie z globalną kolejnością.
5. Selekcja i sortowanie odbywają się po stronie ESP32-S3, nie tylko w aplikacji telefonu.
6. Po zmianie listy urządzenie odświeża prezentację z uwzględnieniem ograniczeń e-paper.

**Warunek brzegowy:** jeśli liczba użytkowników z aktywnymi zadaniami przekracza liczbę pozycji mieszczących się na ekranie, należy zaprojektować rotację stron lub inny mechanizm gwarantujący reprezentację każdej osoby w czasie. Dokładna polityka wymaga decyzji.

## 5. Synchronizacja BLE

- Aplikacja wyszukuje urządzenie w zasięgu przez BLE, bez znajomości jego sieci lub adresu IP.
- Po nawiązaniu krótkiego połączenia przesyła zmiany zadań i odbiera aktualny stan niezbędny do synchronizacji.
- Po zakończeniu transmisji rozłącza się.
- Wiele telefonów może synchronizować zadania z jednym ESP32-S3, kolejno.
- System powinien obsługiwać ponowienie po przerwanym połączeniu, unikać duplikatów i nie tracić zmian.
- Konflikty edycji, usunięcia i ukończenia tego samego zadania na różnych urządzeniach wymagają jednoznacznej polityki rozstrzygania.
- Należy określić, czy synchronizacja następuje wyłącznie ręcznie, czy także automatycznie w dozwolonych przez iOS warunkach.

## 6. Przypomnienia

- Użytkownik może ustawić osobne przypomnienie dla każdego zadania.
- Aplikacja iOS generuje lokalne powiadomienia o ustalonej porze, również bez aktywnego połączenia BLE.
- Zmiana terminu, zakończenie lub usunięcie zadania odpowiednio aktualizuje albo anuluje zaplanowane przypomnienie.
- ESP32-S3 nie musi odpowiadać za dostarczanie powiadomień na telefony.
- Powiadomienia push z serwera nie są wymagane w podstawowym wariancie systemu.

## 7. Bezpieczeństwo

- Tylko uprawnieni członkowie rodziny mogą dodawać i modyfikować zadania na urządzeniu.
- Wymagane jest rozpoznawanie nadawcy i bezpieczne powiązanie telefonu z urządzeniem.
- Dostęp przez BLE musi być zabezpieczony przed nieautoryzowanymi zapisami.
- Integracja z ChatGPT nie może umożliwiać obcym osobom wywoływania operacji.
- Szczegóły parowania, uwierzytelniania i zarządzania uprawnieniami pozostają do ustalenia.

## 8. Wymagania niefunkcjonalne

- Brak konieczności konfigurowania Wi-Fi po przeniesieniu urządzenia na inne piętro lub do innej części domu.
- Minimalna konfiguracja po stronie każdego telefonu.
- Krótkie sesje BLE i odporność na chwilowy brak zasięgu.
- Czytelny interfejs e-paper, uwzględniający ograniczoną powierzchnię i częstotliwość odświeżania.
- Możliwość korzystania z aplikacji i przypomnień, gdy ESP32-S3 jest poza zasięgiem.
- Przechowywanie danych na ESP32-S3 w sposób odporny na restart urządzenia.

## 9. Zakres MVP

1. Aplikacja iOS: CRUD zadań, właściciel, priorytet, termin, status.
2. Lokalne przypomnienia na iOS.
3. Wykrywanie ESP32-S3 przez BLE oraz synchronizacja zadań z wielu telefonów.
4. Trwałe przechowywanie i scalanie zadań na ESP32-S3.
5. Sortowanie oraz gwarantowanie reprezentacji użytkowników na e-paperze.
6. Bezpieczne dodawanie urządzenia i autoryzacja użytkowników.
7. Prototyp integracji z ChatGPT **dopiero po potwierdzeniu obsługiwanego mechanizmu**.

## 10. Otwarte decyzje projektowe

- Dokładny model integracji ChatGPT z natywną aplikacją iOS, bez publicznego udostępniania prywatnego urządzenia.
- Czy ESP32-S3 jest źródłem prawdy, czy jedynie współdzielonym węzłem synchronizacji; jak działa system, gdy przez dłuższy czas urządzenie jest niedostępne.
- Zasady konfliktów między telefonami, usunięć i wersjonowania rekordów.
- Pojemność ekranu, rotacja stron i zachowanie przy dużej liczbie użytkowników.
- Liczba poziomów priorytetu i traktowanie zadań bez terminu.
- Czy użytkownicy mogą edytować cudze zadania.
- Mechanizm pierwszego parowania i nadawania uprawnień kolejnym osobom.
- Czy przypomnienia mają trafiać wyłącznie do właściciela zadania, czy również do innych domowników.
- Model zasilania ESP32-S3 i częstotliwość odświeżania e-paper.

## 11. Kryteria akceptacji

- Dwa lub więcej telefonów mogą dodać zadania do jednego urządzenia przez BLE bez konfigurowania Wi-Fi.
- Przeniesienie urządzenia między różnymi sieciami domowymi nie wymaga zmiany ustawień telefonów.
- Zadania są wyświetlane według priorytetu i terminu, z reprezentacją każdego aktywnego użytkownika (lub rotacją, gdy ekran jest zbyt mały).
- Zadania i przypisanie do użytkowników pozostają zachowane po restarcie ESP32-S3.
- Po przerwaniu połączenia BLE ponowna synchronizacja nie tworzy duplikatów.
- Przypomnienie iOS pojawia się o ustawionej porze bez konieczności połączenia z ESP32-S3.
- Nieuprawniony telefon nie może modyfikować zadań.
- Integracja ChatGPT przechodzi osobny test wykonalności i bezpieczeństwa przed uznaniem jej za gotową.
