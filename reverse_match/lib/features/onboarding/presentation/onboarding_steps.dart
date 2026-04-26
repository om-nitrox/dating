/// Ordered list of onboarding routes for Hinge-style flow.
/// Used to compute progress bar + next-step navigation.
class OnboardingSteps {
  static const List<String> routes = [
    '/onboarding/name',           // 1
    '/onboarding/dob',            // 2
    '/onboarding/gender',         // 3
    '/onboarding/pronouns',       // 4
    '/onboarding/orientation',    // 5
    '/onboarding/dating-pref',    // 6
    '/onboarding/location',       // 7
    '/onboarding/height',         // 8
    '/onboarding/ethnicity',      // 9
    '/onboarding/children',       // 10
    '/onboarding/family-plans',   // 11
    '/onboarding/hometown',       // 12
    '/onboarding/job',            // 13
    '/onboarding/workplace',      // 14
    '/onboarding/education',      // 15
    '/onboarding/religion',       // 16
    '/onboarding/politics',       // 17
    '/onboarding/languages',      // 18
    '/onboarding/intentions',     // 19
    '/onboarding/relationship',   // 20
    '/onboarding/drinking',       // 21
    '/onboarding/smoking',        // 22
    '/onboarding/marijuana',      // 23
    '/onboarding/drugs',          // 24
    '/onboarding/photos',         // 25
    '/onboarding/prompts',        // 26
    '/onboarding/selfie',         // 27
    '/onboarding/preview',        // 28
    '/onboarding/tutorial',       // 29
  ];

  static int total = routes.length;

  static int indexOf(String route) => routes.indexOf(route);

  static String? next(String current) {
    final i = indexOf(current);
    if (i == -1 || i >= routes.length - 1) return null;
    return routes[i + 1];
  }

  static double progress(String current) {
    final i = indexOf(current);
    if (i == -1) return 0;
    return (i + 1) / routes.length;
  }
}
