### T01 - Add a widget factory

- **Files:** src/Widgets/WidgetFactory.cs
- **Layer:** Application
- **Step type:** foundation
- **Test:** test/Widgets/WidgetFactoryTests.cs
- **Acceptance:**
  - `WidgetFactory.Create()` returns a non-null `Widget`.
  - Zero new build warnings.
- **Covers:** none
- **Depends on:** none
- **Conflicts with:** none
- **Estimated complexity:** S
- **Reversibility:** trivial
- **Pattern refs:**
  - src/Gadgets/GadgetFactory.cs:12 - mirror the factory shape.
  - src/Startup.cs:44 - mirror the DI registration line.
