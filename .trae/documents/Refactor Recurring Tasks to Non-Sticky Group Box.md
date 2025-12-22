I have analyzed the user's request and the codebase. The user wants to improve the display of recurring tasks in the `PlanningScreen`.

### Key Requirements:
1.  **Sticky Header Issue**: The "Today's Habits" (Recurring Tasks) header is currently "sticky" (or fixed at the top) in a way the user dislikes. They want it to behave like the category cards (scroll with the content), BUT they also said "sticking to the top is wrong, they should be like category boxes". Wait, actually, the user said "sticky sticking to the top is wrong" (meaning: *don't* make it sticky?).
    *   *Correction*: The user said "در نمای برنامه ریزی عادت های امروز استیکی چسبیدن به بالا، اشتباهه اونا هم باید مثل باکس های دسته بندی ها باشن" -> "In planning view, today's habits sticking to the top is wrong, they should also be like category boxes".
    *   *Interpretation*: The current implementation (which I might have just planned or they are seeing) puts them in a separate header. They want recurring tasks to be **inside a card** just like the other task groups (Categories), not a separate sticky header.
    *   *Refined Plan*: I will remove the `SliverPersistentHeader` and instead render the recurring tasks section as just another item in the scroll view (a `SliverToBoxAdapter` or part of the list).

2.  **Single Box for All Recurring Tasks**: "همه تسک های تکرار شونده تیو یه باکس باشن مثل دسته بندی و اسمش باشه تسک های تکرار شونده" -> "All recurring tasks should be in one box like a category and its name should be 'Recurring Tasks'".
    *   *Action*: Instead of a list of separate cards for each recurring task (which `_buildRecurringTasksHeader` currently does), I need to create **one container** (like `_buildTaskGroup`) that contains *all* the recurring tasks for that view.
    *   *Title*: "تسک‌های تکرار شونده" (Recurring Tasks).

3.  **UI Consistency**: "آیکون های وضعیت تسک های تکرار شونده دقیقا مثل تسک های عادی باشن و حاشیه و رنگ اضافی نداشته باشن" -> "Status icons of recurring tasks should be exactly like normal tasks and have no extra border/color".
    *   *Current State*: The current `_buildRecurringTaskCard` uses a special 7-day circle row.
    *   *New Requirement*: The user wants them to look "exactly like normal tasks" in terms of status icon (no extra borders/colors).
    *   *Clarification*: "کنار هم چیسده بشن سمت راست نام تسک مثل تسک های عادی و متن تسک کنارش نوشته بشه" -> "Aligned next to each other on the right of the task name like normal tasks, and task text written next to it".
    *   *Wait*: This contradicts the previous instruction of "7 circles". Let's re-read carefully.
    *   *User Input*: "آیکون های وضعیت تسک های تکرار شونده دقیقا مثل تسک های عادی باشن ... و کنار هم چیسده بشن سمت راست نام تسک مثل تسک های عادی و متن تسک کنارش نوشته بشه"
    *   *Interpretation*: The user might be referring to the **list item** inside the "Recurring Tasks" box.
    *   *Conflict*: Previously they asked for 7 circles. Now they say "Status icons... exactly like normal tasks".
    *   *Hypothesis*: The "7 circles" design was for the *card* representing the task. But now they want all recurring tasks in *one box*. Inside that box, each task needs to be listed.
    *   *New Design*:
        *   **Container**: One big card (Category style) titled "Recurring Tasks".
        *   **Items**: A list of tasks inside.
        *   **Item Row**:
            *   Right: Status Icon (Normal style).
            *   Center: Task Title.
            *   Left: 7-day circles? OR did they abandon the 7-day circles?
            *   *Text*: "کنار هم چیسده بشن سمت راست نام تسک مثل تسک های عادی و متن تسک کنارش نوشته بشه" -> "Arranged together on the right of the task name like normal tasks and task text written next to it". This part is confusing. "Arranged together" (plural icons?) or "Aligned"?
            *   *Let's look at the "7 circles" instruction again*: "Design recurring tasks... like category card... instead of 1 checkbox have 7...".
            *   *Re-evaluating*: Maybe the user means: **The 7 circles should be the status icons**.
            *   "Status icons of recurring tasks should be exactly like normal tasks... no extra border/color... arranged next to each other on the right of task name...".
            *   *Hypothesis*: The user wants the **7 circles** to be placed **to the right of the task title**, replacing the single status icon. And these circles should look clean (no extra borders/colors like the current implementation might have).
            *   *Alternative*: They want the **normal status icon** (single) on the right, and maybe the 7 circles elsewhere? No, "Exactly like normal tasks" suggests a single icon.
            *   *Crucial Hint*: "مثل باکس های دسته بندی ها باشن" (Like category boxes). Category boxes have a title, and then a list of tasks.
            *   *Combined Interpretation*:
                1.  **Container**: A "Recurring Tasks" group card.
                2.  **Rows**: Each recurring task is a row.
                3.  **Row Design**:
                    *   **Right**: The 7 circles? Or 1 circle?
                    *   "آیکون های وضعیت ... دقیقا مثل تسک های عادی باشن" -> Status icons exactly like normal. Normal tasks have 1 icon.
                    *   "فقط به جای یه چک باکس 7 تا داشته باشن" (Previous prompt).
                    *   "کنار هم چیده بشن سمت راست نام تسک" -> "Arranged side-by-side to the right of the task name". This strongly implies the **7 circles** should be on the **right side** of the text.
                    *   "مثل تسک های عادی" -> Like normal tasks (which have the icon on the right).
                    *   "حاشیه و رنگ اضافی نداشته باشن" -> No extra borders/colors (The current implementation has `border: isToday ? 2.5 : 1.5` and background colors). They want them simple.
                    *   **Verdict**: The row should be: **[7 Circles] [Task Title]**.
                    *   Wait, standard RTL layout: **[Right: Icon] [Text]**.
                    *   So: **[7 Circles (Side by Side)] [Task Title]**.
                    *   This might look crowded. But "کنار هم چیده بشن سمت راست نام تسک" means exactly that.

### Execution Plan
1.  **Remove Sticky Header**: Change the layout to standard scrolling.
2.  **Create "Recurring Tasks" Group**:
    *   Create a new widget `_buildRecurringTaskGroup` that looks identical to `_buildTaskGroup`.
    *   Title: "تسک‌های تکرار شونده" (Recurring Tasks).
    *   Emoji: 🔁 (or similar).
3.  **Redesign Task Row (Recurring)**:
    *   Inside the group, render each recurring task.
    *   **Layout**: Row.
    *   **Leading (Right in RTL)**: The 7-day circles, arranged horizontally (compactly).
    *   **Body**: Task Title.
    *   **Trailing**: Priority Dot + Menu.
    *   **Circle Style**: "No extra border/color". I will make them simple circles. Filled if done/scheduled, outline if pending? "Exactly like normal task status icon". Normal status is a `HugeIcon`. So 7 `HugeIcon`s?
    *   "اگر روزی رو مثلا ندارن دایره شون کم رنگ باشه ولی باشه" -> "If a day is missing, circle should be faint but present".
    *   I will use 7 small `HugeIcon`s (Circle/Checkmark).

### Detailed Steps for `lib/screens/planning_screen.dart`
1.  **Imports**: Add `dart:math` is NOT needed anymore if I remove sticky header.
2.  **`build` method**:
    *   Remove `CustomScrollView` (or keep it but remove `SliverPersistentHeader`).
    *   Actually, `CustomScrollView` is good for performance if I have many slivers. But standard `ListView` is easier if I just want a list of boxes.
    *   The user wants "Recurring Tasks" box to be **just another box** like categories.
    *   So I can inject this "Recurring Group" into the list of groups in `_buildMainContent`.
3.  **`_buildMainContent`**:
    *   In `_buildDailyView` (and others), I need to separate recurring tasks.
    *   Create a list `recurringTasks`.
    *   Create a list `regularTasks`.
    *   Render `_buildRecurringTaskGroup(recurringTasks)` **first**.
    *   Then render `_buildTaskGroup`s for regular tasks.
4.  **`_buildRecurringTaskGroup`**:
    *   Copy style from `_buildTaskGroup`.
    *   Iterate tasks.
    *   Row:
        *   **Right**: Row of 7 icons (Status Icons).
        *   **Center**: Title.
5.  **Refine 7-Icons**:
    *   Use `_getStatusIconData` for the icon shape.
    *   Use `_getStatusColor` for color.
    *   Size: Small (e.g., 16-18).
    *   Padding: Small.

Let's implement.