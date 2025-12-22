I will implement the requested improvements for the "Create New Task" experience.

### 1. **Duplicate Task Feature**
- **File:** `lib/widgets/task_card.dart`
- **Action:** Add a "Duplicate" (`تکثیر تسک`) option to the task popup menu.
- **Logic:** This will open the `AddTaskScreen` with the existing task's data pre-filled, but with a new ID (effectively creating a copy).

### 2. **Task Creation Screen Improvements**
- **File:** `lib/screens/add_task_screen.dart`
- **Sticky Submit Button:**
  - Move the "Register and Start" (`ثبت و شروع کار`) button outside the scrollable area to the bottom of the screen, ensuring it's always visible.
- **Compact Categories:**
  - Adjust the `FilterChip` widgets for categories to be more compact (`visualDensity: VisualDensity.compact`, `materialTapTargetSize: MaterialTapTargetSize.shrinkWrap`).
- **Emoji Handling:**
  - **Input:** Replace the custom emoji picker with a simple dialog containing a `TextField` that allows the user to use their system keyboard (supporting skin tones and native emojis).
  - **Placeholder:** Use '🫥' as the visual placeholder when no emoji is selected.
- **Optional Time:**
  - Introduce logic to make the time component of the due date optional.
  - Add a way to clear/unset the time.
  - Store the "has time" state (likely in metadata) so the UI knows whether to display the time or just the date.
- **Recurrence (Repeat) Logic & UI:**
  - **UI Label:** Change "Due Date" (`زمان انجام`) to "Start Date" (`زمان شروع`) when a recurrence rule is active.
  - **Subtitle:** Remove the redundant "Start: [Date]" text from the recurrence description.
  - **Settings Sheet:**
    - Prevent the sheet from closing immediately upon selection.
    - Add a "Confirm" (`تایید`) button at the bottom of the sheet.
    - Make the sheet layout more compact.

### 3. **Verification**
- I will verify the changes by checking the code for logical correctness and ensuring all UI requirements (sticky button, optional time, duplicate option, emoji input) are implemented as requested.
