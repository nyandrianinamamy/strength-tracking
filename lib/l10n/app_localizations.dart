import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Kotrana: Musculation'**
  String get appTitle;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back,'**
  String get welcomeBack;

  /// No description provided for @athlete.
  ///
  /// In en, this message translates to:
  /// **'Athlete'**
  String get athlete;

  /// No description provided for @workouts.
  ///
  /// In en, this message translates to:
  /// **'WORKOUTS'**
  String get workouts;

  /// No description provided for @recentPrs.
  ///
  /// In en, this message translates to:
  /// **'RECENT PRS'**
  String get recentPrs;

  /// No description provided for @newBadge.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newBadge;

  /// No description provided for @nextWorkout.
  ///
  /// In en, this message translates to:
  /// **'Next Workout'**
  String get nextWorkout;

  /// No description provided for @activeWorkout.
  ///
  /// In en, this message translates to:
  /// **'Active Workout'**
  String get activeWorkout;

  /// No description provided for @startSession.
  ///
  /// In en, this message translates to:
  /// **'START SESSION'**
  String get startSession;

  /// No description provided for @resumeSession.
  ///
  /// In en, this message translates to:
  /// **'RESUME SESSION'**
  String get resumeSession;

  /// No description provided for @readyToTrain.
  ///
  /// In en, this message translates to:
  /// **'Ready to train'**
  String get readyToTrain;

  /// No description provided for @sessionInProgress.
  ///
  /// In en, this message translates to:
  /// **'Session in progress'**
  String get sessionInProgress;

  /// No description provided for @noRoutineAvailable.
  ///
  /// In en, this message translates to:
  /// **'No routine available'**
  String get noRoutineAvailable;

  /// No description provided for @createRoutineToStart.
  ///
  /// In en, this message translates to:
  /// **'Create a routine to start training.'**
  String get createRoutineToStart;

  /// No description provided for @recentWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Recent Workouts'**
  String get recentWorkouts;

  /// No description provided for @viewProgress.
  ///
  /// In en, this message translates to:
  /// **'View Progress'**
  String get viewProgress;

  /// No description provided for @noCompletedWorkouts.
  ///
  /// In en, this message translates to:
  /// **'No completed workouts yet'**
  String get noCompletedWorkouts;

  /// No description provided for @startRoutinePrompt.
  ///
  /// In en, this message translates to:
  /// **'Start a routine and your recent sessions will appear here.'**
  String get startRoutinePrompt;

  /// No description provided for @workoutFrequency.
  ///
  /// In en, this message translates to:
  /// **'Workout Frequency'**
  String get workoutFrequency;

  /// No description provided for @recentPrsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent PRs'**
  String get recentPrsTitle;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @estimated1rm.
  ///
  /// In en, this message translates to:
  /// **'Engine 1RM'**
  String get estimated1rm;

  /// No description provided for @noPrsYet.
  ///
  /// In en, this message translates to:
  /// **'No PRs detected yet'**
  String get noPrsYet;

  /// No description provided for @prsWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Your strongest sets will surface here as soon as you complete a session.'**
  String get prsWillAppear;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @exercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercises;

  /// No description provided for @newExercise.
  ///
  /// In en, this message translates to:
  /// **'New Exercise'**
  String get newExercise;

  /// No description provided for @searchExercises.
  ///
  /// In en, this message translates to:
  /// **'Search exercises or muscles'**
  String get searchExercises;

  /// No description provided for @noExercisesFound.
  ///
  /// In en, this message translates to:
  /// **'No exercises found'**
  String get noExercisesFound;

  /// No description provided for @adjustFilter.
  ///
  /// In en, this message translates to:
  /// **'Adjust the filter or create a custom movement.'**
  String get adjustFilter;

  /// No description provided for @workoutLibrary.
  ///
  /// In en, this message translates to:
  /// **'Workout Library'**
  String get workoutLibrary;

  /// No description provided for @searchRoutines.
  ///
  /// In en, this message translates to:
  /// **'Search routines'**
  String get searchRoutines;

  /// No description provided for @createNewRoutine.
  ///
  /// In en, this message translates to:
  /// **'Create New Routine'**
  String get createNewRoutine;

  /// No description provided for @designPlan.
  ///
  /// In en, this message translates to:
  /// **'Design your own personalized training plan'**
  String get designPlan;

  /// No description provided for @noRoutinesMatch.
  ///
  /// In en, this message translates to:
  /// **'No routines match that filter'**
  String get noRoutinesMatch;

  /// No description provided for @clearSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Clear the search or create a new routine template.'**
  String get clearSearchPrompt;

  /// No description provided for @performanceLab.
  ///
  /// In en, this message translates to:
  /// **'Performance Lab'**
  String get performanceLab;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @lifts.
  ///
  /// In en, this message translates to:
  /// **'Lifts'**
  String get lifts;

  /// No description provided for @volumeTab.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volumeTab;

  /// No description provided for @workoutDays.
  ///
  /// In en, this message translates to:
  /// **'Workout Days'**
  String get workoutDays;

  /// No description provided for @perWeekAverage.
  ///
  /// In en, this message translates to:
  /// **'Per week average'**
  String get perWeekAverage;

  /// No description provided for @consistency.
  ///
  /// In en, this message translates to:
  /// **'Consistency'**
  String get consistency;

  /// No description provided for @thisWeekProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed} / {target} this week'**
  String thisWeekProgress(Object completed, Object target);

  /// No description provided for @weeksOnTrack.
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =0{No weeks on track yet} =1{1 week on track} other{{weeks} weeks on track}}'**
  String weeksOnTrack(num weeks);

  /// No description provided for @personalRecords.
  ///
  /// In en, this message translates to:
  /// **'Personal Records'**
  String get personalRecords;

  /// No description provided for @weeklyVolume.
  ///
  /// In en, this message translates to:
  /// **'Weekly Volume'**
  String get weeklyVolume;

  /// No description provided for @noVolumeData.
  ///
  /// In en, this message translates to:
  /// **'No volume data yet'**
  String get noVolumeData;

  /// No description provided for @completeWorkoutsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Complete workouts to populate the weekly volume chart.'**
  String get completeWorkoutsPrompt;

  /// No description provided for @letsGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Get Started'**
  String get letsGetStarted;

  /// No description provided for @whatShouldWeCallYou.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get whatShouldWeCallYou;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @chooseYourUnit.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Unit'**
  String get chooseYourUnit;

  /// No description provided for @changeAnytime.
  ///
  /// In en, this message translates to:
  /// **'You can change this anytime'**
  String get changeAnytime;

  /// No description provided for @kilograms.
  ///
  /// In en, this message translates to:
  /// **'Kilograms'**
  String get kilograms;

  /// No description provided for @pounds.
  ///
  /// In en, this message translates to:
  /// **'Pounds'**
  String get pounds;

  /// No description provided for @startTraining.
  ///
  /// In en, this message translates to:
  /// **'Start Training'**
  String get startTraining;

  /// No description provided for @tryWithDemoData.
  ///
  /// In en, this message translates to:
  /// **'Explore with Demo Data'**
  String get tryWithDemoData;

  /// No description provided for @inviteOnlyMessage.
  ///
  /// In en, this message translates to:
  /// **'Access to Kotrana is currently invite-only. If you\'ve been invited, sign in with the method linked to your account.'**
  String get inviteOnlyMessage;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signInWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Email'**
  String get signInWithEmail;

  /// No description provided for @orSignIn.
  ///
  /// In en, this message translates to:
  /// **'or sign in to restore your data'**
  String get orSignIn;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed'**
  String get signInFailed;

  /// No description provided for @workoutComplete.
  ///
  /// In en, this message translates to:
  /// **'Workout Complete'**
  String get workoutComplete;

  /// No description provided for @newPersonalRecord.
  ///
  /// In en, this message translates to:
  /// **'New Personal Record!'**
  String get newPersonalRecord;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'DURATION'**
  String get duration;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get total;

  /// No description provided for @prHighlights.
  ///
  /// In en, this message translates to:
  /// **'PR Highlights'**
  String get prHighlights;

  /// No description provided for @noNewPrs.
  ///
  /// In en, this message translates to:
  /// **'No new PRs this time'**
  String get noNewPrs;

  /// No description provided for @prContributes.
  ///
  /// In en, this message translates to:
  /// **'The workout still contributes to your volume and lift history.'**
  String get prContributes;

  /// No description provided for @exerciseBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Exercise Breakdown'**
  String get exerciseBreakdown;

  /// No description provided for @howDidItFeel.
  ///
  /// In en, this message translates to:
  /// **'How did it feel?'**
  String get howDidItFeel;

  /// No description provided for @easy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get easy;

  /// No description provided for @hard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get hard;

  /// No description provided for @finishGoHome.
  ///
  /// In en, this message translates to:
  /// **'Finish & Go Home'**
  String get finishGoHome;

  /// No description provided for @viewProgressCharts.
  ///
  /// In en, this message translates to:
  /// **'View Progression Charts'**
  String get viewProgressCharts;

  /// No description provided for @deleteWorkout.
  ///
  /// In en, this message translates to:
  /// **'Delete Workout?'**
  String get deleteWorkout;

  /// No description provided for @deleteWorkoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will permanently remove this workout and all its logged sets.'**
  String get deleteWorkoutConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @noActiveSession.
  ///
  /// In en, this message translates to:
  /// **'No active session'**
  String get noActiveSession;

  /// No description provided for @startFromDashboard.
  ///
  /// In en, this message translates to:
  /// **'Start a routine from the dashboard or library to begin logging sets.'**
  String get startFromDashboard;

  /// No description provided for @backToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Back to dashboard'**
  String get backToDashboard;

  /// No description provided for @restTimer.
  ///
  /// In en, this message translates to:
  /// **'REST TIMER'**
  String get restTimer;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get ready;

  /// No description provided for @countdown.
  ///
  /// In en, this message translates to:
  /// **'COUNTDOWN'**
  String get countdown;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @weightUnit.
  ///
  /// In en, this message translates to:
  /// **'WEIGHT ({unit})'**
  String weightUnit(Object unit);

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'REPS'**
  String get reps;

  /// No description provided for @log.
  ///
  /// In en, this message translates to:
  /// **'LOG'**
  String get log;

  /// No description provided for @manualMin.
  ///
  /// In en, this message translates to:
  /// **'MANUAL (MIN)'**
  String get manualMin;

  /// No description provided for @addComment.
  ///
  /// In en, this message translates to:
  /// **'ADD COMMENT'**
  String get addComment;

  /// No description provided for @commentAdded.
  ///
  /// In en, this message translates to:
  /// **'COMMENT ADDED'**
  String get commentAdded;

  /// No description provided for @setComment.
  ///
  /// In en, this message translates to:
  /// **'Set Comment'**
  String get setComment;

  /// No description provided for @setCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Optional cue or RPE note for this set'**
  String get setCommentHint;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @currentSessionSets.
  ///
  /// In en, this message translates to:
  /// **'Current Session Sets'**
  String get currentSessionSets;

  /// No description provided for @nothingLoggedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet'**
  String get nothingLoggedYet;

  /// No description provided for @setsWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Your sets for the current exercise will appear here.'**
  String get setsWillAppear;

  /// No description provided for @previousPerformance.
  ///
  /// In en, this message translates to:
  /// **'Previous Performance'**
  String get previousPerformance;

  /// No description provided for @noHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No history for this movement yet'**
  String get noHistoryYet;

  /// No description provided for @historyWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Once you repeat the exercise, prior sets will show here.'**
  String get historyWillAppear;

  /// No description provided for @nextExerciseIn.
  ///
  /// In en, this message translates to:
  /// **'Next exercise in'**
  String get nextExerciseIn;

  /// No description provided for @stayHere.
  ///
  /// In en, this message translates to:
  /// **'Stay Here'**
  String get stayHere;

  /// No description provided for @finishWorkout.
  ///
  /// In en, this message translates to:
  /// **'Finish Workout?'**
  String get finishWorkout;

  /// No description provided for @sessionSaved.
  ///
  /// In en, this message translates to:
  /// **'Your session will be saved and you can review your summary.'**
  String get sessionSaved;

  /// No description provided for @finishSave.
  ///
  /// In en, this message translates to:
  /// **'Finish & Save'**
  String get finishSave;

  /// No description provided for @keepTraining.
  ///
  /// In en, this message translates to:
  /// **'Keep Training'**
  String get keepTraining;

  /// No description provided for @discardSession.
  ///
  /// In en, this message translates to:
  /// **'Discard Session'**
  String get discardSession;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'FINISH'**
  String get finish;

  /// No description provided for @editSet.
  ///
  /// In en, this message translates to:
  /// **'Edit Set'**
  String get editSet;

  /// No description provided for @deleteSet.
  ///
  /// In en, this message translates to:
  /// **'Delete Set'**
  String get deleteSet;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @swapExercise.
  ///
  /// In en, this message translates to:
  /// **'Swap Exercise'**
  String get swapExercise;

  /// No description provided for @newRoutine.
  ///
  /// In en, this message translates to:
  /// **'New Routine'**
  String get newRoutine;

  /// No description provided for @editRoutine.
  ///
  /// In en, this message translates to:
  /// **'Edit Routine'**
  String get editRoutine;

  /// No description provided for @routineName.
  ///
  /// In en, this message translates to:
  /// **'Routine Name'**
  String get routineName;

  /// No description provided for @routineNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Upper Body Power'**
  String get routineNameHint;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @strength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get strength;

  /// No description provided for @hypertrophy.
  ///
  /// In en, this message translates to:
  /// **'Hypertrophy'**
  String get hypertrophy;

  /// No description provided for @mobility.
  ///
  /// In en, this message translates to:
  /// **'Mobility'**
  String get mobility;

  /// No description provided for @tapToAddExercises.
  ///
  /// In en, this message translates to:
  /// **'Tap to add exercises'**
  String get tapToAddExercises;

  /// No description provided for @tapToAddMore.
  ///
  /// In en, this message translates to:
  /// **'Tap to add more exercises'**
  String get tapToAddMore;

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'SETS'**
  String get sets;

  /// No description provided for @rest.
  ///
  /// In en, this message translates to:
  /// **'REST'**
  String get rest;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'DURATION'**
  String get durationLabel;

  /// No description provided for @recommendedWeight.
  ///
  /// In en, this message translates to:
  /// **'Recommended weight'**
  String get recommendedWeight;

  /// No description provided for @createRoutine.
  ///
  /// In en, this message translates to:
  /// **'Create Routine'**
  String get createRoutine;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @searchExercisesEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Search exercises...'**
  String get searchExercisesEllipsis;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get added;

  /// No description provided for @newExerciseTitle.
  ///
  /// In en, this message translates to:
  /// **'New Exercise'**
  String get newExerciseTitle;

  /// No description provided for @editExercise.
  ///
  /// In en, this message translates to:
  /// **'Edit Exercise'**
  String get editExercise;

  /// No description provided for @exerciseName.
  ///
  /// In en, this message translates to:
  /// **'Exercise Name'**
  String get exerciseName;

  /// No description provided for @exerciseNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Incline Dumbbell Press'**
  String get exerciseNameHint;

  /// No description provided for @primaryMuscles.
  ///
  /// In en, this message translates to:
  /// **'Primary Muscles'**
  String get primaryMuscles;

  /// No description provided for @secondaryMuscles.
  ///
  /// In en, this message translates to:
  /// **'Secondary Muscles'**
  String get secondaryMuscles;

  /// No description provided for @secondaryMusclesHint.
  ///
  /// In en, this message translates to:
  /// **'Muscles that assist during the movement'**
  String get secondaryMusclesHint;

  /// No description provided for @equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment;

  /// No description provided for @instructionsFormTips.
  ///
  /// In en, this message translates to:
  /// **'Instructions & Form Tips'**
  String get instructionsFormTips;

  /// No description provided for @instructionsHint.
  ///
  /// In en, this message translates to:
  /// **'Describe setup, execution cues, and common errors to avoid.'**
  String get instructionsHint;

  /// No description provided for @linkedAccount.
  ///
  /// In en, this message translates to:
  /// **'Linked Account'**
  String get linkedAccount;

  /// No description provided for @dataSynced.
  ///
  /// In en, this message translates to:
  /// **'Your data is synced across all your devices.'**
  String get dataSynced;

  /// No description provided for @switchAccount.
  ///
  /// In en, this message translates to:
  /// **'or switch to an existing account'**
  String get switchAccount;

  /// No description provided for @switchWarning.
  ///
  /// In en, this message translates to:
  /// **'This signs out of the current account and loads the selected account\'s cloud data.'**
  String get switchWarning;

  /// No description provided for @signInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInGoogle;

  /// No description provided for @signInApple.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get signInApple;

  /// No description provided for @switchAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Account?'**
  String get switchAccountTitle;

  /// No description provided for @switchAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'You will be signed out of the current account and the selected account\'s cloud data will be loaded.'**
  String get switchAccountConfirm;

  /// No description provided for @switchButton.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchButton;

  /// No description provided for @signedInRestored.
  ///
  /// In en, this message translates to:
  /// **'Signed in and data restored'**
  String get signedInRestored;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out?'**
  String get signOutTitle;

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'You will be signed out and returned to the onboarding screen. Your data remains saved in the cloud.'**
  String get signOutConfirm;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and all synced Kotrana data. This cannot be undone.'**
  String get deleteAccountConfirm;

  /// No description provided for @unitPreference.
  ///
  /// In en, this message translates to:
  /// **'Unit Preference'**
  String get unitPreference;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @loadSampleData.
  ///
  /// In en, this message translates to:
  /// **'Load Sample Exercises & Routines'**
  String get loadSampleData;

  /// No description provided for @sampleDataLoaded.
  ///
  /// In en, this message translates to:
  /// **'Sample exercises & routines loaded'**
  String get sampleDataLoaded;

  /// No description provided for @clearData.
  ///
  /// In en, this message translates to:
  /// **'Clear Exercises & Routines'**
  String get clearData;

  /// No description provided for @clearDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Exercises & Routines?'**
  String get clearDataTitle;

  /// No description provided for @clearDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will delete all exercises and routines. Your workout history will be kept.'**
  String get clearDataConfirm;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @dataCleared.
  ///
  /// In en, this message translates to:
  /// **'Exercises & routines cleared'**
  String get dataCleared;

  /// No description provided for @forceUpdateApp.
  ///
  /// In en, this message translates to:
  /// **'Force Update App'**
  String get forceUpdateApp;

  /// No description provided for @muscleHeatmap.
  ///
  /// In en, this message translates to:
  /// **'Muscle Heatmap'**
  String get muscleHeatmap;

  /// No description provided for @activeMuscles.
  ///
  /// In en, this message translates to:
  /// **'Active muscles'**
  String get activeMuscles;

  /// No description provided for @activeMusclesDesc.
  ///
  /// In en, this message translates to:
  /// **'Muscles targeted by this exercise (pulsing)'**
  String get activeMusclesDesc;

  /// No description provided for @secondaryMusclesLabel.
  ///
  /// In en, this message translates to:
  /// **'Secondary muscles'**
  String get secondaryMusclesLabel;

  /// No description provided for @secondaryMusclesDesc.
  ///
  /// In en, this message translates to:
  /// **'Assisting muscles for this exercise'**
  String get secondaryMusclesDesc;

  /// No description provided for @recovered.
  ///
  /// In en, this message translates to:
  /// **'Recovered'**
  String get recovered;

  /// No description provided for @fatigued.
  ///
  /// In en, this message translates to:
  /// **'Fatigued'**
  String get fatigued;

  /// No description provided for @fatigueDecayNote.
  ///
  /// In en, this message translates to:
  /// **'Fatigue colors fade as muscles recover (~48h half-life)'**
  String get fatigueDecayNote;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @muscleChest.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get muscleChest;

  /// No description provided for @muscleBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get muscleBack;

  /// No description provided for @muscleShoulders.
  ///
  /// In en, this message translates to:
  /// **'Shoulders'**
  String get muscleShoulders;

  /// No description provided for @muscleBiceps.
  ///
  /// In en, this message translates to:
  /// **'Biceps'**
  String get muscleBiceps;

  /// No description provided for @muscleTriceps.
  ///
  /// In en, this message translates to:
  /// **'Triceps'**
  String get muscleTriceps;

  /// No description provided for @muscleAbs.
  ///
  /// In en, this message translates to:
  /// **'Abs'**
  String get muscleAbs;

  /// No description provided for @muscleQuads.
  ///
  /// In en, this message translates to:
  /// **'Quads'**
  String get muscleQuads;

  /// No description provided for @muscleHamstrings.
  ///
  /// In en, this message translates to:
  /// **'Hamstrings'**
  String get muscleHamstrings;

  /// No description provided for @muscleGlutes.
  ///
  /// In en, this message translates to:
  /// **'Glutes'**
  String get muscleGlutes;

  /// No description provided for @muscleLegs.
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get muscleLegs;

  /// No description provided for @equipBarbell.
  ///
  /// In en, this message translates to:
  /// **'Barbell'**
  String get equipBarbell;

  /// No description provided for @equipDumbbells.
  ///
  /// In en, this message translates to:
  /// **'Dumbbells'**
  String get equipDumbbells;

  /// No description provided for @equipBench.
  ///
  /// In en, this message translates to:
  /// **'Bench'**
  String get equipBench;

  /// No description provided for @equipRack.
  ///
  /// In en, this message translates to:
  /// **'Rack'**
  String get equipRack;

  /// No description provided for @equipMachine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get equipMachine;

  /// No description provided for @equipCableMachine.
  ///
  /// In en, this message translates to:
  /// **'Cable Machine'**
  String get equipCableMachine;

  /// No description provided for @equipPullUpBar.
  ///
  /// In en, this message translates to:
  /// **'Pull-Up Bar'**
  String get equipPullUpBar;

  /// No description provided for @equipPlate.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get equipPlate;

  /// No description provided for @exercise_barbell_bench_press.
  ///
  /// In en, this message translates to:
  /// **'Barbell Bench Press'**
  String get exercise_barbell_bench_press;

  /// No description provided for @exercise_incline_barbell_press.
  ///
  /// In en, this message translates to:
  /// **'Incline Barbell Press'**
  String get exercise_incline_barbell_press;

  /// No description provided for @exercise_decline_barbell_press.
  ///
  /// In en, this message translates to:
  /// **'Decline Barbell Press'**
  String get exercise_decline_barbell_press;

  /// No description provided for @exercise_dumbbell_bench_press.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Bench Press'**
  String get exercise_dumbbell_bench_press;

  /// No description provided for @exercise_incline_dumbbell_press.
  ///
  /// In en, this message translates to:
  /// **'Incline Dumbbell Press'**
  String get exercise_incline_dumbbell_press;

  /// No description provided for @exercise_cable_fly.
  ///
  /// In en, this message translates to:
  /// **'Cable Fly'**
  String get exercise_cable_fly;

  /// No description provided for @exercise_pec_deck.
  ///
  /// In en, this message translates to:
  /// **'Pec Deck'**
  String get exercise_pec_deck;

  /// No description provided for @exercise_push_up.
  ///
  /// In en, this message translates to:
  /// **'Push-Up'**
  String get exercise_push_up;

  /// No description provided for @exercise_barbell_row.
  ///
  /// In en, this message translates to:
  /// **'Barbell Row'**
  String get exercise_barbell_row;

  /// No description provided for @exercise_dumbbell_row.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Row'**
  String get exercise_dumbbell_row;

  /// No description provided for @exercise_lat_pulldown.
  ///
  /// In en, this message translates to:
  /// **'Lat Pulldown'**
  String get exercise_lat_pulldown;

  /// No description provided for @exercise_pull_up.
  ///
  /// In en, this message translates to:
  /// **'Pull-Up'**
  String get exercise_pull_up;

  /// No description provided for @exercise_chin_up.
  ///
  /// In en, this message translates to:
  /// **'Chin-Up'**
  String get exercise_chin_up;

  /// No description provided for @exercise_seated_cable_row.
  ///
  /// In en, this message translates to:
  /// **'Seated Cable Row'**
  String get exercise_seated_cable_row;

  /// No description provided for @exercise_t_bar_row.
  ///
  /// In en, this message translates to:
  /// **'T-Bar Row'**
  String get exercise_t_bar_row;

  /// No description provided for @exercise_face_pull.
  ///
  /// In en, this message translates to:
  /// **'Face Pull'**
  String get exercise_face_pull;

  /// No description provided for @exercise_overhead_press.
  ///
  /// In en, this message translates to:
  /// **'Overhead Press'**
  String get exercise_overhead_press;

  /// No description provided for @exercise_dumbbell_shoulder_press.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Shoulder Press'**
  String get exercise_dumbbell_shoulder_press;

  /// No description provided for @exercise_lateral_raise.
  ///
  /// In en, this message translates to:
  /// **'Lateral Raise'**
  String get exercise_lateral_raise;

  /// No description provided for @exercise_front_raise.
  ///
  /// In en, this message translates to:
  /// **'Front Raise'**
  String get exercise_front_raise;

  /// No description provided for @exercise_rear_delt_fly.
  ///
  /// In en, this message translates to:
  /// **'Rear Delt Fly'**
  String get exercise_rear_delt_fly;

  /// No description provided for @exercise_arnold_press.
  ///
  /// In en, this message translates to:
  /// **'Arnold Press'**
  String get exercise_arnold_press;

  /// No description provided for @exercise_barbell_curl.
  ///
  /// In en, this message translates to:
  /// **'Barbell Curl'**
  String get exercise_barbell_curl;

  /// No description provided for @exercise_dumbbell_curl.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Curl'**
  String get exercise_dumbbell_curl;

  /// No description provided for @exercise_hammer_curl.
  ///
  /// In en, this message translates to:
  /// **'Hammer Curl'**
  String get exercise_hammer_curl;

  /// No description provided for @exercise_preacher_curl.
  ///
  /// In en, this message translates to:
  /// **'Preacher Curl'**
  String get exercise_preacher_curl;

  /// No description provided for @exercise_cable_curl.
  ///
  /// In en, this message translates to:
  /// **'Cable Curl'**
  String get exercise_cable_curl;

  /// No description provided for @exercise_tricep_pushdown.
  ///
  /// In en, this message translates to:
  /// **'Tricep Pushdown'**
  String get exercise_tricep_pushdown;

  /// No description provided for @exercise_overhead_tricep_extension.
  ///
  /// In en, this message translates to:
  /// **'Overhead Tricep Extension'**
  String get exercise_overhead_tricep_extension;

  /// No description provided for @exercise_skull_crusher.
  ///
  /// In en, this message translates to:
  /// **'Skull Crusher'**
  String get exercise_skull_crusher;

  /// No description provided for @exercise_dips.
  ///
  /// In en, this message translates to:
  /// **'Dips'**
  String get exercise_dips;

  /// No description provided for @exercise_close_grip_bench_press.
  ///
  /// In en, this message translates to:
  /// **'Close-Grip Bench Press'**
  String get exercise_close_grip_bench_press;

  /// No description provided for @exercise_barbell_back_squat.
  ///
  /// In en, this message translates to:
  /// **'Barbell Back Squat'**
  String get exercise_barbell_back_squat;

  /// No description provided for @exercise_front_squat.
  ///
  /// In en, this message translates to:
  /// **'Front Squat'**
  String get exercise_front_squat;

  /// No description provided for @exercise_leg_press.
  ///
  /// In en, this message translates to:
  /// **'Leg Press'**
  String get exercise_leg_press;

  /// No description provided for @exercise_leg_extension.
  ///
  /// In en, this message translates to:
  /// **'Leg Extension'**
  String get exercise_leg_extension;

  /// No description provided for @exercise_bulgarian_split_squat.
  ///
  /// In en, this message translates to:
  /// **'Bulgarian Split Squat'**
  String get exercise_bulgarian_split_squat;

  /// No description provided for @exercise_goblet_squat.
  ///
  /// In en, this message translates to:
  /// **'Goblet Squat'**
  String get exercise_goblet_squat;

  /// No description provided for @exercise_hack_squat.
  ///
  /// In en, this message translates to:
  /// **'Hack Squat'**
  String get exercise_hack_squat;

  /// No description provided for @exercise_walking_lunge.
  ///
  /// In en, this message translates to:
  /// **'Walking Lunge'**
  String get exercise_walking_lunge;

  /// No description provided for @exercise_romanian_deadlift.
  ///
  /// In en, this message translates to:
  /// **'Romanian Deadlift'**
  String get exercise_romanian_deadlift;

  /// No description provided for @exercise_lying_leg_curl.
  ///
  /// In en, this message translates to:
  /// **'Lying Leg Curl'**
  String get exercise_lying_leg_curl;

  /// No description provided for @exercise_seated_leg_curl.
  ///
  /// In en, this message translates to:
  /// **'Seated Leg Curl'**
  String get exercise_seated_leg_curl;

  /// No description provided for @exercise_stiff_leg_deadlift.
  ///
  /// In en, this message translates to:
  /// **'Stiff-Leg Deadlift'**
  String get exercise_stiff_leg_deadlift;

  /// No description provided for @exercise_good_morning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get exercise_good_morning;

  /// No description provided for @exercise_hip_thrust.
  ///
  /// In en, this message translates to:
  /// **'Hip Thrust'**
  String get exercise_hip_thrust;

  /// No description provided for @exercise_glute_bridge.
  ///
  /// In en, this message translates to:
  /// **'Glute Bridge'**
  String get exercise_glute_bridge;

  /// No description provided for @exercise_cable_kickback.
  ///
  /// In en, this message translates to:
  /// **'Cable Kickback'**
  String get exercise_cable_kickback;

  /// No description provided for @exercise_step_up.
  ///
  /// In en, this message translates to:
  /// **'Step-Up'**
  String get exercise_step_up;

  /// No description provided for @exercise_crunch.
  ///
  /// In en, this message translates to:
  /// **'Crunch'**
  String get exercise_crunch;

  /// No description provided for @exercise_hanging_leg_raise.
  ///
  /// In en, this message translates to:
  /// **'Hanging Leg Raise'**
  String get exercise_hanging_leg_raise;

  /// No description provided for @exercise_plank.
  ///
  /// In en, this message translates to:
  /// **'Plank'**
  String get exercise_plank;

  /// No description provided for @exercise_cable_woodchop.
  ///
  /// In en, this message translates to:
  /// **'Cable Woodchop'**
  String get exercise_cable_woodchop;

  /// No description provided for @exercise_ab_wheel_rollout.
  ///
  /// In en, this message translates to:
  /// **'Ab Wheel Rollout'**
  String get exercise_ab_wheel_rollout;

  /// No description provided for @exercise_conventional_deadlift.
  ///
  /// In en, this message translates to:
  /// **'Conventional Deadlift'**
  String get exercise_conventional_deadlift;

  /// No description provided for @exercise_sumo_deadlift.
  ///
  /// In en, this message translates to:
  /// **'Sumo Deadlift'**
  String get exercise_sumo_deadlift;

  /// No description provided for @exercise_trap_bar_deadlift.
  ///
  /// In en, this message translates to:
  /// **'Trap Bar Deadlift'**
  String get exercise_trap_bar_deadlift;

  /// No description provided for @exercise_treadmill.
  ///
  /// In en, this message translates to:
  /// **'Treadmill'**
  String get exercise_treadmill;

  /// No description provided for @exercise_stationary_bike.
  ///
  /// In en, this message translates to:
  /// **'Stationary Bike'**
  String get exercise_stationary_bike;

  /// No description provided for @exercise_rowing_machine.
  ///
  /// In en, this message translates to:
  /// **'Rowing Machine'**
  String get exercise_rowing_machine;

  /// No description provided for @exercise_stair_climber.
  ///
  /// In en, this message translates to:
  /// **'Stair Climber'**
  String get exercise_stair_climber;

  /// No description provided for @exercise_elliptical.
  ///
  /// In en, this message translates to:
  /// **'Elliptical'**
  String get exercise_elliptical;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @front.
  ///
  /// In en, this message translates to:
  /// **'FRONT'**
  String get front;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get back;

  /// No description provided for @muscleFatigueMap.
  ///
  /// In en, this message translates to:
  /// **'Muscle Fatigue Map'**
  String get muscleFatigueMap;

  /// No description provided for @heatmapDescription.
  ///
  /// In en, this message translates to:
  /// **'This heatmap shows how much each muscle group has been trained recently.'**
  String get heatmapDescription;

  /// No description provided for @howItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get howItWorks;

  /// No description provided for @heatmapVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume is calculated from weight × reps for each set'**
  String get heatmapVolume;

  /// No description provided for @heatmapDecay.
  ///
  /// In en, this message translates to:
  /// **'Fatigue decays over time — contribution halves every 48 hours'**
  String get heatmapDecay;

  /// No description provided for @heatmapColors.
  ///
  /// In en, this message translates to:
  /// **'Colors range from gray (recovered) to red (highly fatigued)'**
  String get heatmapColors;

  /// No description provided for @heatmapSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary muscles contribute at 50% of primary muscle weight'**
  String get heatmapSecondary;

  /// No description provided for @allExercisesComplete.
  ///
  /// In en, this message translates to:
  /// **'All exercises complete!'**
  String get allExercisesComplete;

  /// No description provided for @addAnotherOrFinish.
  ///
  /// In en, this message translates to:
  /// **'Add another exercise or finish your workout.'**
  String get addAnotherOrFinish;

  /// No description provided for @addExercise.
  ///
  /// In en, this message translates to:
  /// **'Add Exercise'**
  String get addExercise;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @archiveRoutine.
  ///
  /// In en, this message translates to:
  /// **'Archive Routine'**
  String get archiveRoutine;

  /// No description provided for @archiveRoutineTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this routine?'**
  String get archiveRoutineTitle;

  /// No description provided for @archiveRoutineConfirm.
  ///
  /// In en, this message translates to:
  /// **'The routine will be hidden from your library, but all workout history will be preserved.'**
  String get archiveRoutineConfirm;

  /// No description provided for @smartPlannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Planner'**
  String get smartPlannerTitle;

  /// No description provided for @generateSmartPlan.
  ///
  /// In en, this message translates to:
  /// **'Generate Smart Plan'**
  String get generateSmartPlan;

  /// No description provided for @smartPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI-powered weekly training plan'**
  String get smartPlanSubtitle;

  /// No description provided for @trainingDays.
  ///
  /// In en, this message translates to:
  /// **'Training Days'**
  String get trainingDays;

  /// No description provided for @goalAndDuration.
  ///
  /// In en, this message translates to:
  /// **'Goal & Duration'**
  String get goalAndDuration;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @trainingGoal.
  ///
  /// In en, this message translates to:
  /// **'Training Goal'**
  String get trainingGoal;

  /// No description provided for @maxSessionDuration.
  ///
  /// In en, this message translates to:
  /// **'Max Session Duration'**
  String get maxSessionDuration;

  /// No description provided for @preferredExercises.
  ///
  /// In en, this message translates to:
  /// **'Preferred Exercises'**
  String get preferredExercises;

  /// No description provided for @preferredExercisesHint.
  ///
  /// In en, this message translates to:
  /// **'These will be prioritized in your plan.'**
  String get preferredExercisesHint;

  /// No description provided for @excludedExercises.
  ///
  /// In en, this message translates to:
  /// **'Excluded Exercises'**
  String get excludedExercises;

  /// No description provided for @excludedExercisesHint.
  ///
  /// In en, this message translates to:
  /// **'These will be excluded from your plan.'**
  String get excludedExercisesHint;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @regenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get regenerate;

  /// No description provided for @adoptPlan.
  ///
  /// In en, this message translates to:
  /// **'Adopt Plan'**
  String get adoptPlan;

  /// No description provided for @yourPlan.
  ///
  /// In en, this message translates to:
  /// **'Your Plan'**
  String get yourPlan;

  /// No description provided for @sessionsPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{count} sessions per week'**
  String sessionsPerWeek(Object count);

  /// No description provided for @noAlternatives.
  ///
  /// In en, this message translates to:
  /// **'No alternatives available'**
  String get noAlternatives;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @readinessEmptyCold.
  ///
  /// In en, this message translates to:
  /// **'Complete a workout and sync HealthKit to unlock your readiness score.'**
  String get readinessEmptyCold;

  /// No description provided for @readinessEmptyColdNoHealthKit.
  ///
  /// In en, this message translates to:
  /// **'Enable HealthKit to improve your readiness accuracy with sleep and HRV data.'**
  String get readinessEmptyColdNoHealthKit;

  /// No description provided for @readinessEmptyAcwrOnly.
  ///
  /// In en, this message translates to:
  /// **'Sync HealthKit to add sleep and HRV data to your readiness score.'**
  String get readinessEmptyAcwrOnly;

  /// No description provided for @readinessEmptyNoHrv.
  ///
  /// In en, this message translates to:
  /// **'HRV tracking needs 3+ days of data. Keep wearing your device.'**
  String get readinessEmptyNoHrv;

  /// No description provided for @readinessEmptyManualOnly.
  ///
  /// In en, this message translates to:
  /// **'Log a workout to unlock objective readiness tracking.'**
  String get readinessEmptyManualOnly;

  /// No description provided for @readinessLimitedData.
  ///
  /// In en, this message translates to:
  /// **'Limited data'**
  String get readinessLimitedData;

  /// No description provided for @syncedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Synced just now'**
  String get syncedJustNow;

  /// No description provided for @syncedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'Synced {minutes}m ago'**
  String syncedMinutesAgo(Object minutes);

  /// No description provided for @syncedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'Synced {hours}h ago'**
  String syncedHoursAgo(Object hours);

  /// No description provided for @syncedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Synced {days}d ago'**
  String syncedDaysAgo(Object days);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @sex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get sex;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @weeklyTrainingTarget.
  ///
  /// In en, this message translates to:
  /// **'Weekly training target'**
  String get weeklyTrainingTarget;

  /// No description provided for @weeklyTrainingTargetDetail.
  ///
  /// In en, this message translates to:
  /// **'Rest days are expected; consistency is measured by weeks on target.'**
  String get weeklyTrainingTargetDetail;

  /// No description provided for @daysPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day / week} other{{days} days / week}}'**
  String daysPerWeek(num days);

  /// No description provided for @fitnessGoal.
  ///
  /// In en, this message translates to:
  /// **'Fitness Goal'**
  String get fitnessGoal;

  /// No description provided for @goalStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get goalStrength;

  /// No description provided for @goalHypertrophy.
  ///
  /// In en, this message translates to:
  /// **'Hypertrophy'**
  String get goalHypertrophy;

  /// No description provided for @goalEndurance.
  ///
  /// In en, this message translates to:
  /// **'Endurance'**
  String get goalEndurance;

  /// No description provided for @goalWeightLoss.
  ///
  /// In en, this message translates to:
  /// **'Weight Loss'**
  String get goalWeightLoss;

  /// No description provided for @goalGeneralFitness.
  ///
  /// In en, this message translates to:
  /// **'General Fitness'**
  String get goalGeneralFitness;

  /// No description provided for @integrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get integrations;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @aboutYou.
  ///
  /// In en, this message translates to:
  /// **'About You'**
  String get aboutYou;

  /// No description provided for @years.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get years;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navRoutines.
  ///
  /// In en, this message translates to:
  /// **'Routines'**
  String get navRoutines;

  /// No description provided for @navProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get navProgress;

  /// No description provided for @offlineMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline — changes saved locally'**
  String get offlineMessage;

  /// No description provided for @backOnline.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get backOnline;

  /// No description provided for @workoutSummary.
  ///
  /// In en, this message translates to:
  /// **'Workout Summary'**
  String get workoutSummary;

  /// No description provided for @summaryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Summary unavailable'**
  String get summaryUnavailable;

  /// No description provided for @workoutNotFound.
  ///
  /// In en, this message translates to:
  /// **'That workout could not be found.'**
  String get workoutNotFound;

  /// No description provided for @resumeStaleSession.
  ///
  /// In en, this message translates to:
  /// **'Resume stale session?'**
  String get resumeStaleSession;

  /// No description provided for @staleSessionMessage.
  ///
  /// In en, this message translates to:
  /// **'This workout has been idle for {duration}. You can resume it, finish it now, or discard it.'**
  String staleSessionMessage(Object duration);

  /// No description provided for @finishNow.
  ///
  /// In en, this message translates to:
  /// **'Finish now'**
  String get finishNow;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @noMatchingExercises.
  ///
  /// In en, this message translates to:
  /// **'No matching exercises'**
  String get noMatchingExercises;

  /// No description provided for @switchNow.
  ///
  /// In en, this message translates to:
  /// **'Switch now'**
  String get switchNow;

  /// No description provided for @logSetRpe.
  ///
  /// In en, this message translates to:
  /// **'Log Set RPE'**
  String get logSetRpe;

  /// No description provided for @selectRpe.
  ///
  /// In en, this message translates to:
  /// **'Select RPE:'**
  String get selectRpe;

  /// No description provided for @whatThisMeans.
  ///
  /// In en, this message translates to:
  /// **'What this means'**
  String get whatThisMeans;

  /// No description provided for @personalBest.
  ///
  /// In en, this message translates to:
  /// **'PB'**
  String get personalBest;

  /// No description provided for @durationMin.
  ///
  /// In en, this message translates to:
  /// **'Duration (min)'**
  String get durationMin;

  /// No description provided for @weightWithUnit.
  ///
  /// In en, this message translates to:
  /// **'Weight ({unit})'**
  String weightWithUnit(Object unit);

  /// No description provided for @repsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get repsLabel;

  /// No description provided for @rpeLabel.
  ///
  /// In en, this message translates to:
  /// **'RPE'**
  String get rpeLabel;

  /// No description provided for @rpeHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, 1-10'**
  String get rpeHint;

  /// No description provided for @noSuggestionYet.
  ///
  /// In en, this message translates to:
  /// **'No suggestion yet'**
  String get noSuggestionYet;

  /// No description provided for @sessionNoValidRoutine.
  ///
  /// In en, this message translates to:
  /// **'Session has no valid routine'**
  String get sessionNoValidRoutine;

  /// No description provided for @routineDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'The routine for this session may have been deleted. Discard this session to continue.'**
  String get routineDeletedMessage;

  /// No description provided for @editSetNumber.
  ///
  /// In en, this message translates to:
  /// **'Edit Set {number}'**
  String editSetNumber(Object number);

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get newGroup;

  /// No description provided for @editGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit Group'**
  String get editGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Push / Pull / Legs'**
  String get groupNameHint;

  /// No description provided for @useAsActiveRotation.
  ///
  /// In en, this message translates to:
  /// **'Use as active rotation'**
  String get useAsActiveRotation;

  /// No description provided for @activeGroupDrivesDashboard.
  ///
  /// In en, this message translates to:
  /// **'The active group drives the dashboard recommendation.'**
  String get activeGroupDrivesDashboard;

  /// No description provided for @orderedRoutines.
  ///
  /// In en, this message translates to:
  /// **'Ordered routines'**
  String get orderedRoutines;

  /// No description provided for @orderedRoutinesDescription.
  ///
  /// In en, this message translates to:
  /// **'These run in sequence. You can reorder them and skip one from the dashboard when needed.'**
  String get orderedRoutinesDescription;

  /// No description provided for @addAtLeastTwoRoutines.
  ///
  /// In en, this message translates to:
  /// **'Add at least two routines'**
  String get addAtLeastTwoRoutines;

  /// No description provided for @chooseRoutinesForSplit.
  ///
  /// In en, this message translates to:
  /// **'Choose the routines that belong to this split.'**
  String get chooseRoutinesForSplit;

  /// No description provided for @addRoutines.
  ///
  /// In en, this message translates to:
  /// **'Add Routines'**
  String get addRoutines;

  /// No description provided for @allRoutinesAssigned.
  ///
  /// In en, this message translates to:
  /// **'All routines are already assigned'**
  String get allRoutinesAssigned;

  /// No description provided for @addMoreRoutines.
  ///
  /// In en, this message translates to:
  /// **'Add more routines'**
  String get addMoreRoutines;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroup;

  /// No description provided for @deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete Group'**
  String get deleteGroup;

  /// No description provided for @deleteGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete group?'**
  String get deleteGroupConfirm;

  /// No description provided for @deleteGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes the sequence, but keeps all routines and workout history.'**
  String get deleteGroupMessage;

  /// No description provided for @addRoutineSheet.
  ///
  /// In en, this message translates to:
  /// **'Add routine'**
  String get addRoutineSheet;

  /// No description provided for @routineGroups.
  ///
  /// In en, this message translates to:
  /// **'Routine Groups'**
  String get routineGroups;

  /// No description provided for @newGroupTooltip.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroupTooltip;

  /// No description provided for @routineGroupsDescription.
  ///
  /// In en, this message translates to:
  /// **'Build ordered splits like PPL or Upper/Lower and choose which one drives the dashboard recommendation.'**
  String get routineGroupsDescription;

  /// No description provided for @noRoutineGroupsYet.
  ///
  /// In en, this message translates to:
  /// **'No routine groups yet'**
  String get noRoutineGroupsYet;

  /// No description provided for @createGroupToSequence.
  ///
  /// In en, this message translates to:
  /// **'Create a group to turn Next Workout into a real sequence.'**
  String get createGroupToSequence;

  /// No description provided for @activeLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeLabel;

  /// No description provided for @nRoutines.
  ///
  /// In en, this message translates to:
  /// **'{count} routines'**
  String nRoutines(Object count);

  /// No description provided for @currentCycle.
  ///
  /// In en, this message translates to:
  /// **'Current cycle: {names}'**
  String currentCycle(Object names);

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @noActiveGroup.
  ///
  /// In en, this message translates to:
  /// **'No active group'**
  String get noActiveGroup;

  /// No description provided for @createGroupPrompt.
  ///
  /// In en, this message translates to:
  /// **'Create a routine group to drive your dashboard sequence.'**
  String get createGroupPrompt;

  /// No description provided for @nRoutinesInRotation.
  ///
  /// In en, this message translates to:
  /// **'{count} routines in rotation'**
  String nRoutinesInRotation(Object count);

  /// No description provided for @createLabel.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createLabel;

  /// No description provided for @manageLabel.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manageLabel;

  /// No description provided for @sleepAndHrv.
  ///
  /// In en, this message translates to:
  /// **'Sleep & HRV'**
  String get sleepAndHrv;

  /// No description provided for @sleepHrvDescription.
  ///
  /// In en, this message translates to:
  /// **'Read sleep and heart rate variability data to improve training recommendations.'**
  String get sleepHrvDescription;

  /// No description provided for @failedError.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String failedError(Object error);

  /// No description provided for @clearWorkoutHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear Workout History'**
  String get clearWorkoutHistory;

  /// No description provided for @clearWorkoutHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear Workout History?'**
  String get clearWorkoutHistoryConfirm;

  /// No description provided for @clearWorkoutHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete all workout sessions and performance data. Your exercises and routines will be kept.'**
  String get clearWorkoutHistoryMessage;

  /// No description provided for @workoutHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Workout history cleared'**
  String get workoutHistoryCleared;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @appleHealth.
  ///
  /// In en, this message translates to:
  /// **'Apple Health'**
  String get appleHealth;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @muscleFatigue.
  ///
  /// In en, this message translates to:
  /// **'Muscle Fatigue'**
  String get muscleFatigue;

  /// No description provided for @engineDebug.
  ///
  /// In en, this message translates to:
  /// **'Engine Debug'**
  String get engineDebug;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @workoutPaused.
  ///
  /// In en, this message translates to:
  /// **'Workout paused'**
  String get workoutPaused;

  /// No description provided for @workoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workoutLabel;

  /// No description provided for @reviewSession.
  ///
  /// In en, this message translates to:
  /// **'Review session'**
  String get reviewSession;

  /// No description provided for @nExercisesRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} exercises remaining'**
  String nExercisesRemaining(Object count);

  /// No description provided for @estimated1rmTracked.
  ///
  /// In en, this message translates to:
  /// **'Engine rolling 1RM tracked automatically'**
  String get estimated1rmTracked;

  /// No description provided for @trainingReadiness.
  ///
  /// In en, this message translates to:
  /// **'Training Readiness'**
  String get trainingReadiness;

  /// No description provided for @adaptiveGuidanceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Adaptive guidance is temporarily unavailable.'**
  String get adaptiveGuidanceUnavailable;

  /// No description provided for @sleepLabel.
  ///
  /// In en, this message translates to:
  /// **'SLEEP'**
  String get sleepLabel;

  /// No description provided for @hrvLabel.
  ///
  /// In en, this message translates to:
  /// **'HRV'**
  String get hrvLabel;

  /// No description provided for @fatigueLabel.
  ///
  /// In en, this message translates to:
  /// **'FATIGUE'**
  String get fatigueLabel;

  /// No description provided for @primedToPerform.
  ///
  /// In en, this message translates to:
  /// **'Primed to perform'**
  String get primedToPerform;

  /// No description provided for @goodToGo.
  ///
  /// In en, this message translates to:
  /// **'Good to go'**
  String get goodToGo;

  /// No description provided for @takeItLighter.
  ///
  /// In en, this message translates to:
  /// **'Take it lighter'**
  String get takeItLighter;

  /// No description provided for @recoveryOptimal.
  ///
  /// In en, this message translates to:
  /// **'Your recovery is optimal today.'**
  String get recoveryOptimal;

  /// No description provided for @recoveryStable.
  ///
  /// In en, this message translates to:
  /// **'Your recovery is stable today.'**
  String get recoveryStable;

  /// No description provided for @giveBodyTime.
  ///
  /// In en, this message translates to:
  /// **'Give your body more time to recover.'**
  String get giveBodyTime;

  /// No description provided for @considerDeload.
  ///
  /// In en, this message translates to:
  /// **'Consider a deload or rest day.'**
  String get considerDeload;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @optimalStatus.
  ///
  /// In en, this message translates to:
  /// **'Optimal'**
  String get optimalStatus;

  /// No description provided for @fairStatus.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get fairStatus;

  /// No description provided for @lowStatus.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get lowStatus;

  /// No description provided for @measuredStatus.
  ///
  /// In en, this message translates to:
  /// **'Measured'**
  String get measuredStatus;

  /// No description provided for @balancedStatus.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get balancedStatus;

  /// No description provided for @moderateValue.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get moderateValue;

  /// No description provided for @highValue.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get highValue;

  /// No description provided for @recoveringStatus.
  ///
  /// In en, this message translates to:
  /// **'Recovering'**
  String get recoveringStatus;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @archiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveLabel;

  /// No description provided for @timedType.
  ///
  /// In en, this message translates to:
  /// **'Timed'**
  String get timedType;

  /// No description provided for @machinePhoto.
  ///
  /// In en, this message translates to:
  /// **'Machine Photo'**
  String get machinePhoto;

  /// No description provided for @addMachinePhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo of the machine'**
  String get addMachinePhoto;

  /// No description provided for @bestTime.
  ///
  /// In en, this message translates to:
  /// **'Best Time'**
  String get bestTime;

  /// No description provided for @bestSet.
  ///
  /// In en, this message translates to:
  /// **'Best Set'**
  String get bestSet;

  /// No description provided for @estimated1rmLong.
  ///
  /// In en, this message translates to:
  /// **'Engine Rolling 1RM'**
  String get estimated1rmLong;

  /// No description provided for @achievedLabel.
  ///
  /// In en, this message translates to:
  /// **'Achieved'**
  String get achievedLabel;

  /// No description provided for @volumeData.
  ///
  /// In en, this message translates to:
  /// **'Volume Data'**
  String get volumeData;

  /// No description provided for @weekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String weekOf(Object date);

  /// No description provided for @whichDaysCommit.
  ///
  /// In en, this message translates to:
  /// **'Which days can you commit to working out?'**
  String get whichDaysCommit;

  /// No description provided for @detectedSplit.
  ///
  /// In en, this message translates to:
  /// **'Detected Split'**
  String get detectedSplit;

  /// No description provided for @nDaysSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} days selected'**
  String nDaysSelected(Object count);

  /// No description provided for @whatTrainingFor.
  ///
  /// In en, this message translates to:
  /// **'What are you training for and how long can you work out?'**
  String get whatTrainingFor;

  /// No description provided for @optionalCustomise.
  ///
  /// In en, this message translates to:
  /// **'Optional — customise which exercises appear in your plan.'**
  String get optionalCustomise;

  /// No description provided for @backButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backButton;

  /// No description provided for @fullBody.
  ///
  /// In en, this message translates to:
  /// **'Full Body'**
  String get fullBody;

  /// No description provided for @upperLower.
  ///
  /// In en, this message translates to:
  /// **'Upper/Lower'**
  String get upperLower;

  /// No description provided for @pushPullLegs.
  ///
  /// In en, this message translates to:
  /// **'Push/Pull/Legs'**
  String get pushPullLegs;

  /// No description provided for @exercisesPrioritised.
  ///
  /// In en, this message translates to:
  /// **'These exercises will be prioritised in your plan.'**
  String get exercisesPrioritised;

  /// No description provided for @exercisesNeverAppear.
  ///
  /// In en, this message translates to:
  /// **'These exercises will never appear in your plan.'**
  String get exercisesNeverAppear;

  /// No description provided for @swapExerciseTitle.
  ///
  /// In en, this message translates to:
  /// **'Swap Exercise'**
  String get swapExerciseTitle;

  /// No description provided for @dayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dayMon;

  /// No description provided for @dayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dayTue;

  /// No description provided for @dayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dayWed;

  /// No description provided for @dayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dayThu;

  /// No description provided for @dayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dayFri;

  /// No description provided for @daySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get daySat;

  /// No description provided for @daySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get daySun;

  /// No description provided for @restTimerComplete.
  ///
  /// In en, this message translates to:
  /// **'Rest timer complete'**
  String get restTimerComplete;

  /// No description provided for @restCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Rest complete. Back to {exercise}.'**
  String restCompleteBody(Object exercise);

  /// No description provided for @nSets.
  ///
  /// In en, this message translates to:
  /// **'{count} sets'**
  String nSets(Object count);

  /// No description provided for @setNColon.
  ///
  /// In en, this message translates to:
  /// **'Set {number}:'**
  String setNColon(Object number);

  /// No description provided for @setNOfM.
  ///
  /// In en, this message translates to:
  /// **'SET {current} OF {total}'**
  String setNOfM(Object current, Object total);

  /// No description provided for @saveAndLogSet.
  ///
  /// In en, this message translates to:
  /// **'Save & Log Set'**
  String get saveAndLogSet;

  /// No description provided for @allExercisesCompleteExcl.
  ///
  /// In en, this message translates to:
  /// **'All exercises complete!'**
  String get allExercisesCompleteExcl;

  /// No description provided for @addAnotherOrFinishWorkout.
  ///
  /// In en, this message translates to:
  /// **'Add another exercise or finish your workout.'**
  String get addAnotherOrFinishWorkout;

  /// No description provided for @exerciseFallback.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exerciseFallback;

  /// No description provided for @routineFallback.
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get routineFallback;

  /// No description provided for @vsLastWeek.
  ///
  /// In en, this message translates to:
  /// **'{delta} vs last week'**
  String vsLastWeek(Object delta);

  /// No description provided for @est1rmValue.
  ///
  /// In en, this message translates to:
  /// **'Est. 1RM: {value}'**
  String est1rmValue(Object value);

  /// No description provided for @setTimedSummary.
  ///
  /// In en, this message translates to:
  /// **'Set {number}: {duration} min'**
  String setTimedSummary(Object number, Object duration);

  /// No description provided for @setWeightSummary.
  ///
  /// In en, this message translates to:
  /// **'Set {number}: {weight} x {reps}'**
  String setWeightSummary(Object number, Object weight, Object reps);

  /// No description provided for @setWeightRpeSummary.
  ///
  /// In en, this message translates to:
  /// **'Set {number}: {weight} x {reps} • RPE {rpe}'**
  String setWeightRpeSummary(
    Object number,
    Object weight,
    Object reps,
    Object rpe,
  );

  /// No description provided for @autoLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
