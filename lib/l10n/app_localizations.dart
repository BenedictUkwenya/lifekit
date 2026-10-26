import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ka.dart';
import 'app_localizations_ru.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('ka'),
    Locale('ru'),
  ];

  /// The application name
  ///
  /// In en, this message translates to:
  /// **'LifeKit'**
  String get appName;

  /// Generic loading state
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edit button label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Done button label
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Confirm button label
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Close button label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Back button label
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Next button label
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Skip button label
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Search placeholder / button
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Empty search results
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get noResults;

  /// See all items link
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// Submit button label
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// Confirmation yes
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// Confirmation no
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Divider word
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// Optional field label
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// Sign in button
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Sign out button
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Sign up link label
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// Create account button
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Forgot password link
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Email field label on signup
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddressLabel;

  /// Email field placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get emailPlaceholder;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Password field placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordPlaceholder;

  /// Confirm password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// Full name field label
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameLabel;

  /// Phone number field label
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneLabel;

  /// Login screen title
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get loginTitle;

  /// Login screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get loginSubtitle;

  /// Login submit button
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginButton;

  /// Prompt to sign up on login screen
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccountPrompt;

  /// Register screen title
  ///
  /// In en, this message translates to:
  /// **'Create Your Account'**
  String get registerTitle;

  /// Register screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Complete the info below to create your account'**
  String get registerSubtitle;

  /// Register submit button
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerButton;

  /// Prompt to sign in on register screen
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccountPrompt;

  /// Continue to next signup step
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// Complete signup button
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// Email required validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get errorEmailRequired;

  /// Email invalid validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get errorEmailInvalid;

  /// Password required validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter a password.'**
  String get errorPasswordRequired;

  /// Password too short validation error
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get errorPasswordShort;

  /// Passwords don't match validation error
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match. Please try again.'**
  String get errorPasswordMatch;

  /// Name required validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name.'**
  String get errorNameRequired;

  /// Login header carousel slide title
  ///
  /// In en, this message translates to:
  /// **'Welcome Back!'**
  String get loginSlideWelcomeBackTitle;

  /// Login header carousel slide subtitle
  ///
  /// In en, this message translates to:
  /// **'Great to see you again 👋'**
  String get loginSlideWelcomeBackSubtitle;

  /// Success toast after login
  ///
  /// In en, this message translates to:
  /// **'Welcome back! 👋'**
  String get welcomeBackToast;

  /// OAuth sign-in error toast
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get signInFailed;

  /// OTP verification step title
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyYourEmail;

  /// Resend OTP link
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get a code? Resend'**
  String get didntGetCodeResend;

  /// Profile photo step title
  ///
  /// In en, this message translates to:
  /// **'Almost done!'**
  String get almostDone;

  /// Profile photo step subtitle
  ///
  /// In en, this message translates to:
  /// **'Add a profile picture — you can always skip this'**
  String get addProfilePictureOptional;

  /// Signup success toast
  ///
  /// In en, this message translates to:
  /// **'Welcome to LifeKit! 🎉'**
  String get welcomeToLifeKit;

  /// Signup completion success toast
  ///
  /// In en, this message translates to:
  /// **'You\'re all set! Welcome to LifeKit 🎉'**
  String get allSetWelcome;

  /// Signup step 1 screen title
  ///
  /// In en, this message translates to:
  /// **'Hi, Welcome to LifeKit'**
  String get signupWelcomeTitle;

  /// Signup password step title
  ///
  /// In en, this message translates to:
  /// **'Choose a password'**
  String get choosePasswordTitle;

  /// Signup password step subtitle
  ///
  /// In en, this message translates to:
  /// **'Pick something secure — at least 6 characters'**
  String get choosePasswordSubtitle;

  /// Splash screen tagline
  ///
  /// In en, this message translates to:
  /// **'...Explore Diversity, Create New Bonds'**
  String get splashTagline;

  /// Onboarding slide 1 title
  ///
  /// In en, this message translates to:
  /// **'Offer Your Skills.\nEarn on Your Terms'**
  String get onboardingOfferSkillsTitle;

  /// Onboarding slide 1 description
  ///
  /// In en, this message translates to:
  /// **'Turn your talent into income by offering your services to a vibrant community that values what you do.'**
  String get onboardingOfferSkillsDesc;

  /// Onboarding slide 2 title
  ///
  /// In en, this message translates to:
  /// **'Book Trusted\nServices Anytime,\nAnywhere'**
  String get onboardingBookServicesTitle;

  /// Onboarding slide 2 description
  ///
  /// In en, this message translates to:
  /// **'Get access to reliable services near you, from beauty to home repairs, wellness, personal care, and more - all in one app.'**
  String get onboardingBookServicesDesc;

  /// Onboarding slide 3 title
  ///
  /// In en, this message translates to:
  /// **'Where Community\nMeets Opportunity'**
  String get onboardingCommunityTitle;

  /// Onboarding slide 3 description
  ///
  /// In en, this message translates to:
  /// **'Connect, share, and grow with people who get you.'**
  String get onboardingCommunityDesc;

  /// Get started button on onboarding
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Forgot password screen title
  ///
  /// In en, this message translates to:
  /// **'Reset your\npassword'**
  String get resetYourPassword;

  /// Forgot password instructions
  ///
  /// In en, this message translates to:
  /// **'Enter the email associated with your account. We\'ll send you a link to reset your password.'**
  String get resetPasswordInstructions;

  /// Forgot password submit button
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// Forgot password success title
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// Forgot password spam hint
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive it? Check your spam folder.'**
  String get checkSpamFolder;

  /// Return to login from forgot password
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// Reset password screen title
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get setNewPasswordTitle;

  /// Reset password screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Choose a strong password for your account.'**
  String get setNewPasswordSubtitle;

  /// Reset password submit button
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePasswordButton;

  /// Reset password success title
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get passwordUpdatedTitle;

  /// Reset password success message
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed. You can sign in with your new password.'**
  String get passwordUpdatedMessage;

  /// Invalid reset link title
  ///
  /// In en, this message translates to:
  /// **'Link expired'**
  String get resetLinkInvalidTitle;

  /// Invalid reset link message
  ///
  /// In en, this message translates to:
  /// **'This password reset link is invalid or has expired. Request a new one.'**
  String get resetLinkInvalidMessage;

  /// Forgot password success body with email
  ///
  /// In en, this message translates to:
  /// **'We sent a password reset link to\n{email}'**
  String emailSentTo(String email);

  /// Retry forgot password with another email
  ///
  /// In en, this message translates to:
  /// **'Try a different email'**
  String get tryDifferentEmail;

  /// AI onboarding screen title
  ///
  /// In en, this message translates to:
  /// **'AI Setup Guide'**
  String get aiSetupGuide;

  /// AI onboarding loading message
  ///
  /// In en, this message translates to:
  /// **'AI is analyzing your profile…'**
  String get aiAnalyzingProfile;

  /// AI onboarding field label
  ///
  /// In en, this message translates to:
  /// **'Your Goals'**
  String get yourGoals;

  /// AI onboarding goals placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g. Earn extra income, find reliable service providers'**
  String get yourGoalsHint;

  /// AI onboarding field label
  ///
  /// In en, this message translates to:
  /// **'Your Skills'**
  String get yourSkills;

  /// AI onboarding skills placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g. Cooking, plumbing, teaching, graphic design'**
  String get yourSkillsHint;

  /// AI onboarding field label
  ///
  /// In en, this message translates to:
  /// **'Your Interests'**
  String get yourInterests;

  /// AI onboarding interests placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g. Music, food, fitness, technology'**
  String get yourInterestsHint;

  /// AI onboarding CTA button
  ///
  /// In en, this message translates to:
  /// **'Generate My 7-Day Plan'**
  String get generateMySevenDayPlan;

  /// AI onboarding completion button
  ///
  /// In en, this message translates to:
  /// **'Finish & Go to Home'**
  String get finishAndGoToHome;

  /// AI plan day card action button
  ///
  /// In en, this message translates to:
  /// **'Take Action'**
  String get takeAction;

  /// AI plan generation error
  ///
  /// In en, this message translates to:
  /// **'Failed to generate plan. Please try again.'**
  String get failedToGeneratePlan;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get navFeeds;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get navChats;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTabDiscover;

  /// Feed tab label
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get homeTabFeed;

  /// Bookings tab label
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get homeTabBookings;

  /// Groups tab label
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get homeTabGroups;

  /// Profile tab label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get homeTabProfile;

  /// AI recommended section header
  ///
  /// In en, this message translates to:
  /// **'Recommended for You'**
  String get homeAIRecommended;

  /// Trending section header
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get homeTrending;

  /// Near you section header
  ///
  /// In en, this message translates to:
  /// **'Near You'**
  String get homeNearYou;

  /// Home search hint
  ///
  /// In en, this message translates to:
  /// **'Search services, providers...'**
  String get searchServicesProviders;

  /// Quick action and settings label
  ///
  /// In en, this message translates to:
  /// **'My Bookings'**
  String get myBookings;

  /// Quick action label
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get rewards;

  /// Explore section CTA
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// Popular badge and tab label
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// Home and groups screen title
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get communities;

  /// Communities section tagline
  ///
  /// In en, this message translates to:
  /// **'Find your tribe, share your world'**
  String get findYourTribe;

  /// Home section header
  ///
  /// In en, this message translates to:
  /// **'Popular Providers'**
  String get popularProviders;

  /// Recent searches section header
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// Dismiss dialog button
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get maybeLater;

  /// Bookings screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get bookingTitle;

  /// Upcoming bookings tab
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get bookingUpcoming;

  /// Past bookings tab
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get bookingPast;

  /// Pending bookings tab
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get bookingPending;

  /// Bookings tab label
  ///
  /// In en, this message translates to:
  /// **'Client Requests'**
  String get clientRequests;

  /// Bookings tab label
  ///
  /// In en, this message translates to:
  /// **'My Swaps'**
  String get mySwaps;

  /// Booking status: pending
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get bookingStatusPending;

  /// Booking status: confirmed
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get bookingStatusConfirmed;

  /// Booking status: completed
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get bookingStatusCompleted;

  /// Booking status: cancelled
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get bookingStatusCancelled;

  /// Cancel booking button
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking'**
  String get bookingCancelButton;

  /// Confirm booking cancellation dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this booking?'**
  String get bookingConfirmCancel;

  /// Empty upcoming bookings state
  ///
  /// In en, this message translates to:
  /// **'No service booked yet.'**
  String get bookingNoUpcoming;

  /// Empty past bookings state
  ///
  /// In en, this message translates to:
  /// **'No requests received yet.'**
  String get bookingNoPast;

  /// Booking filter chip
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get filterOngoing;

  /// Booking filter chip
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get filterCompleted;

  /// Booking filter chip
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get filterUpcoming;

  /// Provider accept booking snackbar
  ///
  /// In en, this message translates to:
  /// **'Request Accepted! Client notified.'**
  String get requestAccepted;

  /// Provider reject booking snackbar
  ///
  /// In en, this message translates to:
  /// **'Request Rejected.'**
  String get requestRejected;

  /// Reject booking request button
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// Accept booking request button
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// Open booking tracking button
  ///
  /// In en, this message translates to:
  /// **'Track Status'**
  String get trackStatus;

  /// Urgent booking time badge
  ///
  /// In en, this message translates to:
  /// **'🔴 Happening Now!'**
  String get happeningNow;

  /// Relative time next day
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get tomorrow;

  /// Booking status label
  ///
  /// In en, this message translates to:
  /// **'Waiting Approval'**
  String get waitingApproval;

  /// Skill Swap FAB label
  ///
  /// In en, this message translates to:
  /// **'Skill Swap'**
  String get skillSwap;

  /// Swaps empty state title
  ///
  /// In en, this message translates to:
  /// **'No Swaps Yet'**
  String get noSwapsYet;

  /// Swaps empty state body
  ///
  /// In en, this message translates to:
  /// **'Exchange skills with others.\nBrowse the Swap Board to find your first match.'**
  String get noSwapsYetDescription;

  /// Swaps empty state CTA
  ///
  /// In en, this message translates to:
  /// **'Browse Swap Board'**
  String get browseSwapBoard;

  /// Confirmed swap status
  ///
  /// In en, this message translates to:
  /// **'Swap Active'**
  String get swapActive;

  /// Complete swap/task button
  ///
  /// In en, this message translates to:
  /// **'Mark Done'**
  String get markDone;

  /// Services screen title
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get servicesTitle;

  /// Price label on service card
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get servicePrice;

  /// Hourly rate suffix
  ///
  /// In en, this message translates to:
  /// **'/ hr'**
  String get serviceHourlyRate;

  /// Add to cart button
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get serviceAddToCart;

  /// Book now button
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get serviceBookNow;

  /// About section on service detail
  ///
  /// In en, this message translates to:
  /// **'About This Service'**
  String get serviceAbout;

  /// Provider section label
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get serviceProvider;

  /// Reviews section label
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get serviceReviews;

  /// Explore empty state title
  ///
  /// In en, this message translates to:
  /// **'No services found'**
  String get noServicesFound;

  /// Explore empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'New services will appear here once available.'**
  String get noServicesFoundSubtitle;

  /// Create service button
  ///
  /// In en, this message translates to:
  /// **'Create Service'**
  String get createService;

  /// Dashboard quick action
  ///
  /// In en, this message translates to:
  /// **'Add\nService'**
  String get addService;

  /// Dashboard quick action
  ///
  /// In en, this message translates to:
  /// **'My\nServices'**
  String get myServices;

  /// Cart screen title
  ///
  /// In en, this message translates to:
  /// **'My Cart'**
  String get cartTitle;

  /// Empty cart message
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty.'**
  String get cartEmpty;

  /// Cart total label
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get cartTotal;

  /// Checkout button
  ///
  /// In en, this message translates to:
  /// **'Confirm Booking'**
  String get cartCheckout;

  /// Remove item from cart
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get cartRemoveItem;

  /// Payment screen title
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentTitle;

  /// Confirm payment button
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment'**
  String get paymentConfirm;

  /// Payment success message
  ///
  /// In en, this message translates to:
  /// **'Booking Confirmed!'**
  String get paymentSuccess;

  /// Payment failed message
  ///
  /// In en, this message translates to:
  /// **'Payment failed. Please try again.'**
  String get paymentFailed;

  /// Stripe cancel snackbar
  ///
  /// In en, this message translates to:
  /// **'Payment Cancelled'**
  String get paymentCancelled;

  /// Profile screen title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Edit profile button
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEdit;

  /// Bookings menu item in profile
  ///
  /// In en, this message translates to:
  /// **'My Bookings'**
  String get profileBookings;

  /// Logout button in profile
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get profileLogout;

  /// Logout confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get profileLogoutConfirm;

  /// Reviews section on profile
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get profileReviews;

  /// Followers count label
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get profileFollowers;

  /// Following count label
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileFollowing;

  /// Follow button
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get profileFollow;

  /// Unfollow button
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get profileUnfollow;

  /// Profile load error
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile'**
  String get failedToLoadProfile;

  /// Empty profile bio
  ///
  /// In en, this message translates to:
  /// **'No bio added'**
  String get noBioAdded;

  /// Profile wallet card label
  ///
  /// In en, this message translates to:
  /// **'Wallet Balance'**
  String get walletBalance;

  /// Trial banner title
  ///
  /// In en, this message translates to:
  /// **'Launch Offer: Pro Trial Active'**
  String get launchOfferProTrial;

  /// Subscription usage section
  ///
  /// In en, this message translates to:
  /// **'Account Usage'**
  String get accountUsage;

  /// Open subscription plans button
  ///
  /// In en, this message translates to:
  /// **'Upgrade Plan'**
  String get upgradePlan;

  /// Founding member badge
  ///
  /// In en, this message translates to:
  /// **'🌟 Founding Member'**
  String get foundingMember;

  /// Profile business tools section
  ///
  /// In en, this message translates to:
  /// **'Business Tools'**
  String get businessTools;

  /// Business tool and settings label
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get generalSettings;

  /// Settings item
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Language setting item
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Notifications setting item
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// Security setting item
  ///
  /// In en, this message translates to:
  /// **'Password & Security'**
  String get settingsSecurity;

  /// Help & support setting item
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get settingsHelp;

  /// About setting item
  ///
  /// In en, this message translates to:
  /// **'About LifeKit'**
  String get settingsAbout;

  /// Delete account setting item
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get settingsDeleteAccount;

  /// Settings item
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// Support section header
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// Logout settings item
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// Wallet screen title
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletTitle;

  /// Top up wallet button
  ///
  /// In en, this message translates to:
  /// **'Top Up'**
  String get walletTopUp;

  /// Withdraw from wallet button
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get walletWithdraw;

  /// Transaction history section
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get walletTransactions;

  /// Empty wallet transactions state
  ///
  /// In en, this message translates to:
  /// **'No transactions yet.'**
  String get walletNoTransactions;

  /// Wallet settings snackbar
  ///
  /// In en, this message translates to:
  /// **'Wallet settings are coming soon!'**
  String get walletSettingsComingSoon;

  /// Withdraw dialog title
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// Amount input hint
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get enterAmount;

  /// Withdraw validation
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get enterValidAmount;

  /// Withdraw validation
  ///
  /// In en, this message translates to:
  /// **'Amount exceeds balance.'**
  String get amountExceedsBalance;

  /// Withdraw success snackbar
  ///
  /// In en, this message translates to:
  /// **'Withdrawal completed.'**
  String get withdrawalCompleted;

  /// Wallet stats label
  ///
  /// In en, this message translates to:
  /// **'Weekly Income'**
  String get weeklyIncome;

  /// Wallet points label
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// Wallet action button
  ///
  /// In en, this message translates to:
  /// **'Add Money'**
  String get addMoney;

  /// Stripe connect CTA
  ///
  /// In en, this message translates to:
  /// **'Setup Payouts'**
  String get setupPayouts;

  /// Wallet QR scan button
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// QR scan snackbar
  ///
  /// In en, this message translates to:
  /// **'QR scan payments are coming soon!'**
  String get qrScanComingSoon;

  /// Add money screen title
  ///
  /// In en, this message translates to:
  /// **'Fund Wallet'**
  String get fundWallet;

  /// Deposit minimum validation
  ///
  /// In en, this message translates to:
  /// **'Minimum deposit is \$5'**
  String get minimumDepositFive;

  /// Deposit success snackbar
  ///
  /// In en, this message translates to:
  /// **'Wallet funded successfully!'**
  String get walletFundedSuccessfully;

  /// Add money helper text
  ///
  /// In en, this message translates to:
  /// **'Minimum deposit: \$5.00'**
  String get minimumDepositAmount;

  /// Stripe payment button
  ///
  /// In en, this message translates to:
  /// **'Pay with Card'**
  String get payWithCard;

  /// Payment security badge
  ///
  /// In en, this message translates to:
  /// **'Secured by Stripe'**
  String get securedByStripe;

  /// Groups screen title
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get groupsTitle;

  /// Join group button
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get groupsJoin;

  /// Leave group button
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get groupsLeave;

  /// Members count label
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get groupsMembers;

  /// Create group button
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get groupsCreateGroup;

  /// Empty groups state
  ///
  /// In en, this message translates to:
  /// **'No groups found.'**
  String get groupsNoGroups;

  /// Communities screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Find your people, share your world'**
  String get findYourPeople;

  /// Feed screen title
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get feedTitle;

  /// Feed new post placeholder
  ///
  /// In en, this message translates to:
  /// **'Share something…'**
  String get feedNewPost;

  /// Like post button
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get feedLike;

  /// Comment on post button
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get feedComment;

  /// Share post button
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get feedShare;

  /// Empty feed state
  ///
  /// In en, this message translates to:
  /// **'No posts yet. Be the first to share!'**
  String get feedNoPost;

  /// Places screen title
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get placesTitle;

  /// Places search field hint
  ///
  /// In en, this message translates to:
  /// **'Search restaurants, cafés, hotels...'**
  String get searchPlacesHint;

  /// Empty places state
  ///
  /// In en, this message translates to:
  /// **'No places nearby'**
  String get noPlacesNearby;

  /// Places loading status
  ///
  /// In en, this message translates to:
  /// **'Locating you...'**
  String get locatingYou;

  /// Places fetch status
  ///
  /// In en, this message translates to:
  /// **'Finding places near you...'**
  String get findingPlacesNearYou;

  /// Places category filter
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// Places category filter
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get categoryRestaurant;

  /// Places category filter
  ///
  /// In en, this message translates to:
  /// **'Café'**
  String get categoryCafe;

  /// Places category filter
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get categoryHotel;

  /// Notifications screen title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// Empty notifications state
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get notificationsEmpty;

  /// Mark all notifications as read
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationsMarkAllRead;

  /// Language settings screen title
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Georgian language option
  ///
  /// In en, this message translates to:
  /// **'Georgian'**
  String get languageGeorgian;

  /// Russian language option
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// Georgian language native name
  ///
  /// In en, this message translates to:
  /// **'ქართული'**
  String get languageNativeGeorgian;

  /// Russian language native name
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageNativeRussian;

  /// Free subscription plan
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get subscriptionPlanFree;

  /// Pro subscription plan
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get subscriptionPlanPro;

  /// Business subscription plan
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get subscriptionPlanBusiness;

  /// Upgrade plan button
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get subscriptionUpgrade;

  /// Chat screen title
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatTitle;

  /// Chat input placeholder
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get chatInputPlaceholder;

  /// Chat send button
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// Empty chat state
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Start the conversation!'**
  String get chatNoMessages;

  /// Provider dashboard title
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get providerDashboard;

  /// Dashboard section label
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// Dashboard earnings label
  ///
  /// In en, this message translates to:
  /// **'Total Earnings'**
  String get totalEarnings;

  /// Dashboard period label
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// Dashboard stat label
  ///
  /// In en, this message translates to:
  /// **'Jobs Done'**
  String get jobsDone;

  /// Dashboard stat label
  ///
  /// In en, this message translates to:
  /// **'Avg Rating'**
  String get avgRating;

  /// Dashboard AI section title
  ///
  /// In en, this message translates to:
  /// **'AI Opportunity Radar'**
  String get aiOpportunityRadar;

  /// AI opportunities subtitle
  ///
  /// In en, this message translates to:
  /// **'Services you could offer right now'**
  String get servicesYouCouldOffer;

  /// AI opportunities empty
  ///
  /// In en, this message translates to:
  /// **'No opportunities found right now.'**
  String get noOpportunitiesFound;

  /// AI opportunity CTA
  ///
  /// In en, this message translates to:
  /// **'Create Service'**
  String get createServiceButton;

  /// Reviews screen title
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsTitle;

  /// Write review button
  ///
  /// In en, this message translates to:
  /// **'Write a Review'**
  String get reviewsWriteReview;

  /// Empty reviews state
  ///
  /// In en, this message translates to:
  /// **'No reviews yet.'**
  String get reviewsNoReviews;

  /// Review text placeholder
  ///
  /// In en, this message translates to:
  /// **'Write a comment (optional)...'**
  String get reviewsRatePlaceholder;

  /// Submit review button
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get reviewsSubmit;

  /// Leave review success snackbar
  ///
  /// In en, this message translates to:
  /// **'Review Submitted!'**
  String get reviewSubmitted;

  /// Reviewer name fallback
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get anonymous;

  /// Skill swap screen title
  ///
  /// In en, this message translates to:
  /// **'Skill Swap'**
  String get skillSwapTitle;

  /// Discover swaps tab
  ///
  /// In en, this message translates to:
  /// **'Discover Swaps'**
  String get skillSwapDiscover;

  /// Propose swap button
  ///
  /// In en, this message translates to:
  /// **'Propose a Swap'**
  String get skillSwapPropose;

  /// Accept swap button
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get skillSwapAccept;

  /// Decline swap button
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get skillSwapDecline;

  /// Empty skill swap state
  ///
  /// In en, this message translates to:
  /// **'No swap offers available.'**
  String get skillSwapNoSwaps;

  /// AI assistant screen title
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistantTitle;

  /// AI assistant input placeholder
  ///
  /// In en, this message translates to:
  /// **'Ask me anything about LifeKit…'**
  String get aiAssistantPlaceholder;

  /// AI assistant send button
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get aiAssistantSend;

  /// Fallback provider name
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get providerFallback;

  /// Fallback display name
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userFallback;

  /// Fallback unknown entity
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// Fallback untitled service
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// Transaction status label
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// Chart empty state
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get noDataYet;

  /// Refresh button tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Login slider slide 2 title
  ///
  /// In en, this message translates to:
  /// **'Your Progress Awaits'**
  String get loginSlideProgressTitle;

  /// Login slider slide 2 subtitle
  ///
  /// In en, this message translates to:
  /// **'Keep the momentum going'**
  String get loginSlideProgressSubtitle;

  /// Login slider slide 3 title
  ///
  /// In en, this message translates to:
  /// **'AI Insights Ready'**
  String get loginSlideAITitle;

  /// Login slider slide 3 subtitle
  ///
  /// In en, this message translates to:
  /// **'Fresh personalized recommendations'**
  String get loginSlideAISubtitle;

  /// Login slider slide 4 title
  ///
  /// In en, this message translates to:
  /// **'Your Community'**
  String get loginSlideCommunityTitle;

  /// Login slider slide 4 subtitle
  ///
  /// In en, this message translates to:
  /// **'See what\'s happening in your circle'**
  String get loginSlideCommunitySubtitle;

  /// Signup slider slide 1 subtitle
  ///
  /// In en, this message translates to:
  /// **'Your all-in-one personal growth companion'**
  String get signupSlideWelcomeSubtitle;

  /// Signup slider slide 2 title
  ///
  /// In en, this message translates to:
  /// **'Build Better Habits'**
  String get signupSlideHabitsTitle;

  /// Signup slider slide 2 subtitle
  ///
  /// In en, this message translates to:
  /// **'Track goals, streaks & daily progress'**
  String get signupSlideHabitsSubtitle;

  /// Signup slider slide 3 title
  ///
  /// In en, this message translates to:
  /// **'AI-Powered Coaching'**
  String get signupSlideAITitle;

  /// Signup slider slide 3 subtitle
  ///
  /// In en, this message translates to:
  /// **'Personalized insights that help you grow'**
  String get signupSlideAISubtitle;

  /// Signup slider slide 4 title
  ///
  /// In en, this message translates to:
  /// **'Vibrant Community'**
  String get signupSlideCommunityTitle;

  /// Signup slider slide 4 subtitle
  ///
  /// In en, this message translates to:
  /// **'Connect, share & stay inspired together'**
  String get signupSlideCommunitySubtitle;

  /// Greeting on the home screen with the user's first name
  ///
  /// In en, this message translates to:
  /// **'Hello {name} 👋'**
  String homeHelloGreeting(String name);

  /// Sub-heading under the home greeting
  ///
  /// In en, this message translates to:
  /// **'Explore the shores of delta oceans'**
  String get homeWelcomeTagline;

  /// Headline on the offer banner
  ///
  /// In en, this message translates to:
  /// **'{name}, a special offer awaits!'**
  String homeSpecialOfferAwaits(String name);

  /// Default offer banner title
  ///
  /// In en, this message translates to:
  /// **'Get 20% off your\nfirst booking!'**
  String get homeOfferTitle;

  /// Default offer banner subtitle
  ///
  /// In en, this message translates to:
  /// **'Valid until Oct 30'**
  String get homeOfferValidUntil;

  /// Swap section header
  ///
  /// In en, this message translates to:
  /// **'🔄 Top Swap Opportunities'**
  String get homeTopSwapOpportunities;

  /// Communities count badge on home
  ///
  /// In en, this message translates to:
  /// **'{count} Communities'**
  String homeCommunitiesCount(int count);

  /// Communities browse all button
  ///
  /// In en, this message translates to:
  /// **'Browse All →'**
  String get homeBrowseAll;

  /// Services row CTA chip
  ///
  /// In en, this message translates to:
  /// **'More\nServices'**
  String get homeMoreServices;

  /// Tooltip when user taps their own service
  ///
  /// In en, this message translates to:
  /// **'This is your service. Manage it from My Services.'**
  String get homeMyServiceBadge;

  /// AI daily task card title
  ///
  /// In en, this message translates to:
  /// **'Gracia\'s Daily Task'**
  String get homeDailyTaskTitle;

  /// Day number badge on daily task card
  ///
  /// In en, this message translates to:
  /// **'Day {dayNum}'**
  String homeDailyTaskDay(int dayNum);

  /// Mark daily task done button
  ///
  /// In en, this message translates to:
  /// **'Mark Done'**
  String get homeDailyTaskMarkDone;

  /// Returning user banner with days since last visit
  ///
  /// In en, this message translates to:
  /// **'Welcome back! {days}d of new opportunities'**
  String homeWelcomeBackOpportunities(int days);

  /// Places filter chip
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get homeCategoryNearby;

  /// Places filter chip
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get homeCategoryLocal;

  /// Places filter chip
  ///
  /// In en, this message translates to:
  /// **'Convenient'**
  String get homeCategoryConvenient;

  /// Places filter chip
  ///
  /// In en, this message translates to:
  /// **'Central'**
  String get homeCategoryCentral;

  /// Discover badge on explore header
  ///
  /// In en, this message translates to:
  /// **'✦ Discover'**
  String get exploreDiscoverBadge;

  /// Explore screen header
  ///
  /// In en, this message translates to:
  /// **'Find the best\nservices near you'**
  String get exploreFindBest;

  /// Explore subtitle showing service count
  ///
  /// In en, this message translates to:
  /// **'{count}+ services available'**
  String exploreServicesAvailable(int count);

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Featured Professionals'**
  String get exploreFeaturedProfessionals;

  /// Provider card subtitle
  ///
  /// In en, this message translates to:
  /// **'Featured Professional'**
  String get exploreFeaturedProfessional;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Browse Categories'**
  String get exploreBrowseCategories;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'All Services'**
  String get exploreAllServices;

  /// AI insight banner title
  ///
  /// In en, this message translates to:
  /// **'City Pulse'**
  String get exploreCityPulse;

  /// Tap-to-explore prompt on City Pulse banner
  ///
  /// In en, this message translates to:
  /// **'Tap to explore: {category} →'**
  String exploreTapToExplore(String category);

  /// Badge on the user's own service card
  ///
  /// In en, this message translates to:
  /// **'Your Listing'**
  String get categoryYourListing;

  /// Small badge shown on the user's own service cards in lists
  ///
  /// In en, this message translates to:
  /// **'Your Service'**
  String get homeYourServiceBadge;

  /// Section header on category items screen
  ///
  /// In en, this message translates to:
  /// **'More Providers'**
  String get categoryMoreProviders;

  /// Search results count
  ///
  /// In en, this message translates to:
  /// **'Showing {count} results'**
  String categoryShowingResults(int count);

  /// Search hint that includes the category name
  ///
  /// In en, this message translates to:
  /// **'Search {category}...'**
  String categorySearchHint(String category);

  /// No description provided for @profileNoBio.
  ///
  /// In en, this message translates to:
  /// **'No bio added'**
  String get profileNoBio;

  /// No description provided for @profileBusinessTools.
  ///
  /// In en, this message translates to:
  /// **'Business Tools'**
  String get profileBusinessTools;

  /// No description provided for @profileToolDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get profileToolDashboard;

  /// No description provided for @profileToolServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get profileToolServices;

  /// No description provided for @profileToolAIPremium.
  ///
  /// In en, this message translates to:
  /// **'AI Premium'**
  String get profileToolAIPremium;

  /// No description provided for @profileToolRewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get profileToolRewards;

  /// No description provided for @profileAIPremiumComingSoon.
  ///
  /// In en, this message translates to:
  /// **'AI Premium Tools coming soon!'**
  String get profileAIPremiumComingSoon;

  /// No description provided for @profileRewardsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Rewards coming soon!'**
  String get profileRewardsComingSoon;

  /// No description provided for @profileGeneralSettings.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get profileGeneralSettings;

  /// No description provided for @profileAISetupGuide.
  ///
  /// In en, this message translates to:
  /// **'AI Setup Guide'**
  String get profileAISetupGuide;

  /// No description provided for @profileAISetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate your 7-Day Success Plan'**
  String get profileAISetupSubtitle;

  /// No description provided for @profilePersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get profilePersonalInfo;

  /// No description provided for @profileSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get profileSupport;

  /// No description provided for @tierFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get tierFree;

  /// No description provided for @tierPlus.
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get tierPlus;

  /// No description provided for @tierPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get tierPro;

  /// No description provided for @tierBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get tierBusiness;

  /// No description provided for @securityLoginDetails.
  ///
  /// In en, this message translates to:
  /// **'Login Details'**
  String get securityLoginDetails;

  /// No description provided for @securityCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get securityCurrentPassword;

  /// No description provided for @securityNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get securityNewPassword;

  /// No description provided for @securityConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get securityConfirmPassword;

  /// No description provided for @securityChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get securityChangePassword;

  /// No description provided for @securityForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get securityForgotPassword;

  /// No description provided for @securityAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced Security'**
  String get securityAdvanced;

  /// No description provided for @securityBiometric.
  ///
  /// In en, this message translates to:
  /// **'Biometric Login'**
  String get securityBiometric;

  /// No description provided for @securityBiometricSubtitle.
  ///
  /// In en, this message translates to:
  /// **'FaceID / TouchID'**
  String get securityBiometricSubtitle;

  /// No description provided for @securityTwoFactor.
  ///
  /// In en, this message translates to:
  /// **'Two-Factor Authentication'**
  String get securityTwoFactor;

  /// No description provided for @security2FAComingSoon.
  ///
  /// In en, this message translates to:
  /// **'2FA Setup coming soon'**
  String get security2FAComingSoon;

  /// No description provided for @securityDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get securityDeleteAccount;

  /// No description provided for @securityDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible. All your data will be lost.'**
  String get securityDeleteWarning;

  /// No description provided for @securityDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get securityDelete;

  /// No description provided for @securityCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get securityCancel;

  /// No description provided for @securityPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'New passwords do not match'**
  String get securityPasswordMismatch;

  /// No description provided for @securityPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'New password must be at least 6 characters'**
  String get securityPasswordTooShort;

  /// No description provided for @securityEnterCurrent.
  ///
  /// In en, this message translates to:
  /// **'Please enter your current password'**
  String get securityEnterCurrent;

  /// No description provided for @securityPasswordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully!'**
  String get securityPasswordUpdated;

  /// No description provided for @notifPush.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get notifPush;

  /// No description provided for @notifPushSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive messages and booking updates'**
  String get notifPushSubtitle;

  /// No description provided for @notifEmail.
  ///
  /// In en, this message translates to:
  /// **'Email Notifications'**
  String get notifEmail;

  /// No description provided for @notifEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive receipts and digests'**
  String get notifEmailSubtitle;

  /// No description provided for @notifPromo.
  ///
  /// In en, this message translates to:
  /// **'Promotional Offers'**
  String get notifPromo;

  /// No description provided for @notifPromoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Coupons and news'**
  String get notifPromoSubtitle;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langGeorgian.
  ///
  /// In en, this message translates to:
  /// **'Georgian'**
  String get langGeorgian;

  /// No description provided for @langRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get langRussian;

  /// No description provided for @helpMyTickets.
  ///
  /// In en, this message translates to:
  /// **'My Tickets'**
  String get helpMyTickets;

  /// No description provided for @helpNoTickets.
  ///
  /// In en, this message translates to:
  /// **'No tickets yet'**
  String get helpNoTickets;

  /// No description provided for @helpContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get helpContactSupport;

  /// No description provided for @helpSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get helpSubject;

  /// No description provided for @helpMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get helpMessage;

  /// No description provided for @helpSubmitTicket.
  ///
  /// In en, this message translates to:
  /// **'Submit Ticket'**
  String get helpSubmitTicket;

  /// No description provided for @helpFillBoth.
  ///
  /// In en, this message translates to:
  /// **'Please fill subject and message'**
  String get helpFillBoth;

  /// No description provided for @helpTicketSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Ticket submitted successfully!'**
  String get helpTicketSubmitted;

  /// No description provided for @helpSupportTicketDefault.
  ///
  /// In en, this message translates to:
  /// **'Support Ticket'**
  String get helpSupportTicketDefault;

  /// No description provided for @helpFaqCancelQuestion.
  ///
  /// In en, this message translates to:
  /// **'How do I cancel a booking?'**
  String get helpFaqCancelQuestion;

  /// No description provided for @helpFaqCancelAnswer.
  ///
  /// In en, this message translates to:
  /// **'Go to the bookings tab, select the active booking, and click the \'Cancel\' button.'**
  String get helpFaqCancelAnswer;

  /// No description provided for @helpFaqRefundQuestion.
  ///
  /// In en, this message translates to:
  /// **'How do refunds work?'**
  String get helpFaqRefundQuestion;

  /// No description provided for @helpFaqRefundAnswer.
  ///
  /// In en, this message translates to:
  /// **'Refunds are processed to your wallet immediately after cancellation confirmation.'**
  String get helpFaqRefundAnswer;

  /// No description provided for @walletWeeklyIncome.
  ///
  /// In en, this message translates to:
  /// **'Weekly Income'**
  String get walletWeeklyIncome;

  /// No description provided for @walletPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get walletPoints;

  /// No description provided for @walletPointsOf.
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String walletPointsOf(String total);

  /// No description provided for @walletAddMoney.
  ///
  /// In en, this message translates to:
  /// **'Add Money'**
  String get walletAddMoney;

  /// No description provided for @walletSetupPayouts.
  ///
  /// In en, this message translates to:
  /// **'Setup Payouts'**
  String get walletSetupPayouts;

  /// No description provided for @walletScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get walletScan;

  /// No description provided for @walletTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get walletTransactionHistory;

  /// No description provided for @walletSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get walletSuccess;

  /// No description provided for @walletEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get walletEnterAmount;

  /// No description provided for @walletEnterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get walletEnterValidAmount;

  /// No description provided for @walletAmountExceeds.
  ///
  /// In en, this message translates to:
  /// **'Amount exceeds balance.'**
  String get walletAmountExceeds;

  /// No description provided for @walletWithdrawalCompleted.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal completed.'**
  String get walletWithdrawalCompleted;

  /// No description provided for @walletSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Setup failed: {error}'**
  String walletSetupFailed(String error);

  /// No description provided for @walletWithdrawFailed.
  ///
  /// In en, this message translates to:
  /// **'Withdraw failed: {error}'**
  String walletWithdrawFailed(String error);

  /// No description provided for @feedsTabFeeds.
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get feedsTabFeeds;

  /// No description provided for @feedsTabEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get feedsTabEvents;

  /// No description provided for @feedsWhatsOnYourMind.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind?'**
  String get feedsWhatsOnYourMind;

  /// No description provided for @feedsPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get feedsPhoto;

  /// No description provided for @feedsTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get feedsTag;

  /// No description provided for @feedsPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get feedsPost;

  /// No description provided for @feedsCreatePost.
  ///
  /// In en, this message translates to:
  /// **'Create Post'**
  String get feedsCreatePost;

  /// No description provided for @feedsAddTitleOptional.
  ///
  /// In en, this message translates to:
  /// **'Add a title (optional)'**
  String get feedsAddTitleOptional;

  /// No description provided for @feedsTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get feedsTrending;

  /// No description provided for @feedsLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get feedsLive;

  /// No description provided for @feedsTrendingSkillOffer.
  ///
  /// In en, this message translates to:
  /// **'Skill Offer'**
  String get feedsTrendingSkillOffer;

  /// No description provided for @feedsTrendingTips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get feedsTrendingTips;

  /// No description provided for @feedsTrendingSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get feedsTrendingSwap;

  /// No description provided for @feedsTrendingLookingFor.
  ///
  /// In en, this message translates to:
  /// **'Looking For'**
  String get feedsTrendingLookingFor;

  /// No description provided for @feedsTrendingServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get feedsTrendingServices;

  /// No description provided for @feedsReportPost.
  ///
  /// In en, this message translates to:
  /// **'Report Post'**
  String get feedsReportPost;

  /// No description provided for @feedsPostReported.
  ///
  /// In en, this message translates to:
  /// **'Post reported. Thank you.'**
  String get feedsPostReported;

  /// No description provided for @profilePrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get profilePrivacyPolicy;

  /// No description provided for @profileTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get profileTermsOfService;

  /// No description provided for @feedsBlockUser.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get feedsBlockUser;

  /// No description provided for @feedsBlockUserConfirm.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see each other\'s posts. You can unblock them anytime in Profile → Security → Blocked users.'**
  String get feedsBlockUserConfirm;

  /// No description provided for @feedsUserBlocked.
  ///
  /// In en, this message translates to:
  /// **'User blocked.'**
  String get feedsUserBlocked;

  /// No description provided for @feedsActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get feedsActionFailed;

  /// No description provided for @feedsShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get feedsShare;

  /// No description provided for @feedsSharedFromLifeKit.
  ///
  /// In en, this message translates to:
  /// **'Shared from LifeKit'**
  String get feedsSharedFromLifeKit;

  /// No description provided for @feedsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get feedsDelete;

  /// No description provided for @feedsPostDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted'**
  String get feedsPostDeleted;

  /// No description provided for @feedsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete post: {error}'**
  String feedsDeleteFailed(String error);

  /// No description provided for @feedsLikeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update like: {error}'**
  String feedsLikeFailed(String error);

  /// No description provided for @feedsBookmarkFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update bookmark: {error}'**
  String feedsBookmarkFailed(String error);

  /// No description provided for @feedsJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get feedsJustNow;

  /// No description provided for @feedsMinAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String feedsMinAgo(int count);

  /// No description provided for @feedsHourAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String feedsHourAgo(int count);

  /// No description provided for @feedsDayAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String feedsDayAgo(int count);

  /// No description provided for @eventsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search events...'**
  String get eventsSearchHint;

  /// No description provided for @eventsPopularToday.
  ///
  /// In en, this message translates to:
  /// **'Popular Today'**
  String get eventsPopularToday;

  /// No description provided for @eventsSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get eventsSearchResults;

  /// No description provided for @eventsNoFoundFor.
  ///
  /// In en, this message translates to:
  /// **'No events found for \"{query}\"'**
  String eventsNoFoundFor(String query);

  /// No description provided for @eventsNoInCategory.
  ///
  /// In en, this message translates to:
  /// **'No events in this category'**
  String get eventsNoInCategory;

  /// No description provided for @eventsCatAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get eventsCatAll;

  /// No description provided for @eventsCatTheatre.
  ///
  /// In en, this message translates to:
  /// **'Theatre'**
  String get eventsCatTheatre;

  /// No description provided for @eventsCatSport.
  ///
  /// In en, this message translates to:
  /// **'Sport'**
  String get eventsCatSport;

  /// No description provided for @eventsCatFestival.
  ///
  /// In en, this message translates to:
  /// **'Festival'**
  String get eventsCatFestival;

  /// No description provided for @eventsCatTourism.
  ///
  /// In en, this message translates to:
  /// **'Tourism'**
  String get eventsCatTourism;

  /// No description provided for @eventsCatMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get eventsCatMusic;

  /// No description provided for @eventsCatFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get eventsCatFood;

  /// No description provided for @chatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatsTitle;

  /// No description provided for @chatsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for chats or services...'**
  String get chatsSearchHint;

  /// No description provided for @chatsRecentContacts.
  ///
  /// In en, this message translates to:
  /// **'Recent Contacts'**
  String get chatsRecentContacts;

  /// No description provided for @chatsTabActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get chatsTabActive;

  /// No description provided for @chatsTabFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get chatsTabFinished;

  /// No description provided for @chatsNoActive.
  ///
  /// In en, this message translates to:
  /// **'No active conversations right now'**
  String get chatsNoActive;

  /// No description provided for @chatsPastWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Your past chats will appear here'**
  String get chatsPastWillAppear;

  /// No description provided for @chatsStartingNewComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Starting a new conversation is coming soon!'**
  String get chatsStartingNewComingSoon;

  /// No description provided for @chatsNoMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatsNoMessagesYet;

  /// No description provided for @chatsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get chatsGeneral;

  /// No description provided for @chatsJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get chatsJustNow;

  /// No description provided for @chatsYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatsYesterday;

  /// No description provided for @actionSheetWhatToDo.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do?'**
  String get actionSheetWhatToDo;

  /// No description provided for @actionBookService.
  ///
  /// In en, this message translates to:
  /// **'Book Service'**
  String get actionBookService;

  /// No description provided for @actionBookServiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay & schedule'**
  String get actionBookServiceSubtitle;

  /// No description provided for @actionSkillSwap.
  ///
  /// In en, this message translates to:
  /// **'Skill Swap'**
  String get actionSkillSwap;

  /// No description provided for @actionSkillSwapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trade skills, no money'**
  String get actionSkillSwapSubtitle;

  /// No description provided for @actionNoCash.
  ///
  /// In en, this message translates to:
  /// **'✨ No cash'**
  String get actionNoCash;

  /// No description provided for @badgeSwappable.
  ///
  /// In en, this message translates to:
  /// **'Swappable'**
  String get badgeSwappable;

  /// No description provided for @providerDescription.
  ///
  /// In en, this message translates to:
  /// **'Service Description'**
  String get providerDescription;

  /// No description provided for @providerNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description available.'**
  String get providerNoDescription;

  /// No description provided for @providerAboutProvider.
  ///
  /// In en, this message translates to:
  /// **'About Provider'**
  String get providerAboutProvider;

  /// No description provided for @providerDefaultBio.
  ///
  /// In en, this message translates to:
  /// **'Professional service provider on LifeKit.'**
  String get providerDefaultBio;

  /// No description provided for @providerInstantConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Instant Confirmation'**
  String get providerInstantConfirmation;

  /// No description provided for @providerVerifiedProvider.
  ///
  /// In en, this message translates to:
  /// **'Verified Provider'**
  String get providerVerifiedProvider;

  /// No description provided for @providerTabAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get providerTabAbout;

  /// No description provided for @providerTabReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get providerTabReviews;

  /// No description provided for @providerTabAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get providerTabAvailability;

  /// No description provided for @providerTabServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get providerTabServices;

  /// No description provided for @providerSearchServicesHint.
  ///
  /// In en, this message translates to:
  /// **'Search services...'**
  String get providerSearchServicesHint;

  /// No description provided for @providerBookThisService.
  ///
  /// In en, this message translates to:
  /// **'Book This Service'**
  String get providerBookThisService;

  /// No description provided for @providerRestrictedTitle.
  ///
  /// In en, this message translates to:
  /// **'Restricted'**
  String get providerRestrictedTitle;

  /// No description provided for @providerRestrictedBody.
  ///
  /// In en, this message translates to:
  /// **'You cannot book your own service.'**
  String get providerRestrictedBody;

  /// No description provided for @providerOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get providerOk;

  /// No description provided for @providerOnlineRemote.
  ///
  /// In en, this message translates to:
  /// **'Online/Remote'**
  String get providerOnlineRemote;

  /// No description provided for @providerProviderFallback.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get providerProviderFallback;

  /// No description provided for @providerSharedToFeed.
  ///
  /// In en, this message translates to:
  /// **'Service shared to feed'**
  String get providerSharedToFeed;

  /// No description provided for @providerShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to share service'**
  String get providerShareFailed;

  /// No description provided for @providerPriceVaries.
  ///
  /// In en, this message translates to:
  /// **'Price Varies'**
  String get providerPriceVaries;

  /// No description provided for @providerBookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get providerBookNow;

  /// No description provided for @providerRatingsSummary.
  ///
  /// In en, this message translates to:
  /// **'Ratings Summary'**
  String get providerRatingsSummary;

  /// No description provided for @providerUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get providerUserFallback;

  /// No description provided for @providerVerifiedService.
  ///
  /// In en, this message translates to:
  /// **'Verified Service'**
  String get providerVerifiedService;

  /// No description provided for @providerNoReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get providerNoReviews;

  /// No description provided for @providerBeFirstReview.
  ///
  /// In en, this message translates to:
  /// **'Be the first to review and get {points} reward points'**
  String providerBeFirstReview(int points);

  /// No description provided for @bookTitle.
  ///
  /// In en, this message translates to:
  /// **'Book Service'**
  String get bookTitle;

  /// No description provided for @bookQuickSelect.
  ///
  /// In en, this message translates to:
  /// **'Quick Select'**
  String get bookQuickSelect;

  /// No description provided for @bookToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get bookToday;

  /// No description provided for @bookTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get bookTomorrow;

  /// No description provided for @bookThisWeekend.
  ///
  /// In en, this message translates to:
  /// **'This Weekend'**
  String get bookThisWeekend;

  /// No description provided for @bookTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get bookTotal;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get bookNow;

  /// No description provided for @bookLoadingAvailability.
  ///
  /// In en, this message translates to:
  /// **'Loading availability...'**
  String get bookLoadingAvailability;

  /// No description provided for @bookSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Please select a date'**
  String get bookSelectDate;

  /// No description provided for @bookSelectAtLeastOneOption.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one service option.'**
  String get bookSelectAtLeastOneOption;

  /// No description provided for @bookNoUpcomingAvailability.
  ///
  /// In en, this message translates to:
  /// **'No upcoming availability yet'**
  String get bookNoUpcomingAvailability;

  /// No description provided for @bookProviderOffDay.
  ///
  /// In en, this message translates to:
  /// **'Provider is off that day. Next available: {date}'**
  String bookProviderOffDay(String date);

  /// No description provided for @bookUseNext.
  ///
  /// In en, this message translates to:
  /// **'Use Next'**
  String get bookUseNext;

  /// No description provided for @bookTimeConflict.
  ///
  /// In en, this message translates to:
  /// **'This time slot is already booked.'**
  String get bookTimeConflict;

  /// No description provided for @bookSelectTime.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get bookSelectTime;

  /// No description provided for @bookCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get bookCancel;

  /// No description provided for @bookDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get bookDone;

  /// No description provided for @bookGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get bookGotIt;

  /// No description provided for @bookNoTimeSlots.
  ///
  /// In en, this message translates to:
  /// **'No available time slots'**
  String get bookNoTimeSlots;

  /// No description provided for @bookHoldOn.
  ///
  /// In en, this message translates to:
  /// **'Hold on'**
  String get bookHoldOn;

  /// No description provided for @bookSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get bookSuccess;

  /// No description provided for @bookCommentSaved.
  ///
  /// In en, this message translates to:
  /// **'Comment saved!'**
  String get bookCommentSaved;

  /// No description provided for @bookServiceType.
  ///
  /// In en, this message translates to:
  /// **'Service Type'**
  String get bookServiceType;

  /// No description provided for @bookTypeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get bookTypeDefault;

  /// No description provided for @bookTypeHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get bookTypeHome;

  /// No description provided for @bookTypeOutdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get bookTypeOutdoor;

  /// No description provided for @bookFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get bookFixed;

  /// No description provided for @bookSelectServiceOptions.
  ///
  /// In en, this message translates to:
  /// **'Select Service Options'**
  String get bookSelectServiceOptions;

  /// No description provided for @bookMoreServices.
  ///
  /// In en, this message translates to:
  /// **'More Services'**
  String get bookMoreServices;

  /// No description provided for @bookServiceTime.
  ///
  /// In en, this message translates to:
  /// **'Service Time'**
  String get bookServiceTime;

  /// No description provided for @bookAddInstructions.
  ///
  /// In en, this message translates to:
  /// **'Add special instructions...'**
  String get bookAddInstructions;

  /// No description provided for @swapTitle.
  ///
  /// In en, this message translates to:
  /// **'Skill Swap'**
  String get swapTitle;

  /// No description provided for @swapPoweredBy.
  ///
  /// In en, this message translates to:
  /// **'Powered by Gracia'**
  String get swapPoweredBy;

  /// No description provided for @swapSelectServiceType.
  ///
  /// In en, this message translates to:
  /// **'Select service type'**
  String get swapSelectServiceType;

  /// No description provided for @swapBiDirectional.
  ///
  /// In en, this message translates to:
  /// **'Bi-directional AI matching '**
  String get swapBiDirectional;

  /// No description provided for @swapBiDirectionalDesc.
  ///
  /// In en, this message translates to:
  /// **'finds providers who want what you offer AND offer what you want.'**
  String get swapBiDirectionalDesc;

  /// No description provided for @swapSelectYours.
  ///
  /// In en, this message translates to:
  /// **'Select Yours'**
  String get swapSelectYours;

  /// No description provided for @swapSelectTarget.
  ///
  /// In en, this message translates to:
  /// **'Select Target'**
  String get swapSelectTarget;

  /// No description provided for @swapLookingForSkill.
  ///
  /// In en, this message translates to:
  /// **'Looking for a skill'**
  String get swapLookingForSkill;

  /// No description provided for @swapProposeTo.
  ///
  /// In en, this message translates to:
  /// **'Propose Swap to {name}'**
  String swapProposeTo(String name);

  /// No description provided for @swapFindOtherMatches.
  ///
  /// In en, this message translates to:
  /// **'Find Other AI Matches'**
  String get swapFindOtherMatches;

  /// No description provided for @swapFindMatch.
  ///
  /// In en, this message translates to:
  /// **'Find AI Match'**
  String get swapFindMatch;

  /// No description provided for @swapBrowseBoard.
  ///
  /// In en, this message translates to:
  /// **'Browse Swap Board'**
  String get swapBrowseBoard;

  /// No description provided for @swapSelectSkillToOffer.
  ///
  /// In en, this message translates to:
  /// **'Select a skill to offer'**
  String get swapSelectSkillToOffer;

  /// No description provided for @swapNoServicesCreateFirst.
  ///
  /// In en, this message translates to:
  /// **'No services found. Create a service first.'**
  String get swapNoServicesCreateFirst;

  /// No description provided for @swapSelectSkillCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Skill Category'**
  String get swapSelectSkillCategory;

  /// No description provided for @swapMatchFound.
  ///
  /// In en, this message translates to:
  /// **'Match Found!'**
  String get swapMatchFound;

  /// No description provided for @swapAiMatchingFor.
  ///
  /// In en, this message translates to:
  /// **'AI matching for'**
  String get swapAiMatchingFor;

  /// No description provided for @swapMeLabel.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get swapMeLabel;

  /// No description provided for @swapNoProvidersFound.
  ///
  /// In en, this message translates to:
  /// **'No providers found'**
  String get swapNoProvidersFound;

  /// No description provided for @swapTryDifferentCategory.
  ///
  /// In en, this message translates to:
  /// **'Try a different skill category'**
  String get swapTryDifferentCategory;

  /// No description provided for @swapAiMatched.
  ///
  /// In en, this message translates to:
  /// **'AI Matched'**
  String get swapAiMatched;

  /// No description provided for @swapMatchTag.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get swapMatchTag;

  /// No description provided for @swapRatingNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get swapRatingNew;

  /// No description provided for @swapOtherAiMatches.
  ///
  /// In en, this message translates to:
  /// **'Other AI Matches'**
  String get swapOtherAiMatches;

  /// No description provided for @swapUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get swapUserFallback;

  /// No description provided for @swapSendProposal.
  ///
  /// In en, this message translates to:
  /// **'Send Swap Proposal'**
  String get swapSendProposal;

  /// No description provided for @swapYouOffer.
  ///
  /// In en, this message translates to:
  /// **'You offer'**
  String get swapYouOffer;

  /// No description provided for @swapYouReceive.
  ///
  /// In en, this message translates to:
  /// **'You receive'**
  String get swapYouReceive;

  /// No description provided for @swapPreferredDate.
  ///
  /// In en, this message translates to:
  /// **'Preferred Date'**
  String get swapPreferredDate;

  /// No description provided for @swapMessagePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'E.g. \"Happy to be flexible on timing, let me know!\"'**
  String get swapMessagePlaceholder;

  /// No description provided for @swapSendProposalBtn.
  ///
  /// In en, this message translates to:
  /// **'Send Proposal'**
  String get swapSendProposalBtn;

  /// No description provided for @swapProposalSent.
  ///
  /// In en, this message translates to:
  /// **'Swap Proposal Sent!'**
  String get swapProposalSent;

  /// No description provided for @swapAcceptedToast.
  ///
  /// In en, this message translates to:
  /// **'Swap Accepted! Check your bookings.'**
  String get swapAcceptedToast;

  /// No description provided for @swapDeclinedToast.
  ///
  /// In en, this message translates to:
  /// **'Swap declined.'**
  String get swapDeclinedToast;

  /// No description provided for @swapCancelledToast.
  ///
  /// In en, this message translates to:
  /// **'Swap proposal cancelled.'**
  String get swapCancelledToast;

  /// No description provided for @swapBookingNotFound.
  ///
  /// In en, this message translates to:
  /// **'Booking not found for this swap.'**
  String get swapBookingNotFound;

  /// No description provided for @swapSelectServiceToOffer.
  ///
  /// In en, this message translates to:
  /// **'Please select a service you want to offer.'**
  String get swapSelectServiceToOffer;

  /// No description provided for @swapSelectSkillLookingFor.
  ///
  /// In en, this message translates to:
  /// **'Please select a skill you are looking for.'**
  String get swapSelectSkillLookingFor;

  /// No description provided for @swapServiceFallback.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get swapServiceFallback;

  /// No description provided for @swapProviderFallback.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get swapProviderFallback;

  /// No description provided for @swapDirectSelection.
  ///
  /// In en, this message translates to:
  /// **'Direct service selection'**
  String get swapDirectSelection;

  /// No description provided for @swapPotentialMatch.
  ///
  /// In en, this message translates to:
  /// **'Potential match'**
  String get swapPotentialMatch;

  /// No description provided for @swapGoodMatch.
  ///
  /// In en, this message translates to:
  /// **'Good complementary match'**
  String get swapGoodMatch;

  /// No description provided for @swapUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get swapUnknown;

  /// No description provided for @swapBoardTitle.
  ///
  /// In en, this message translates to:
  /// **'Swap Board'**
  String get swapBoardTitle;

  /// No description provided for @swapBoardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI-ranked matches for you'**
  String get swapBoardSubtitle;

  /// No description provided for @swapTabDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get swapTabDiscover;

  /// No description provided for @swapTabIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get swapTabIncoming;

  /// No description provided for @swapTabOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing'**
  String get swapTabOutgoing;

  /// No description provided for @swapNoSwapsYet.
  ///
  /// In en, this message translates to:
  /// **'No swaps yet'**
  String get swapNoSwapsYet;

  /// No description provided for @swapEnableHint.
  ///
  /// In en, this message translates to:
  /// **'Enable Skill Swap on your services and others will appear here!'**
  String get swapEnableHint;

  /// No description provided for @swapPeopleLookingToTrade.
  ///
  /// In en, this message translates to:
  /// **'People actively looking to trade skills'**
  String get swapPeopleLookingToTrade;

  /// No description provided for @swapServicesFromProviders.
  ///
  /// In en, this message translates to:
  /// **'Services from providers willing to trade'**
  String get swapServicesFromProviders;

  /// No description provided for @swapNoIncoming.
  ///
  /// In en, this message translates to:
  /// **'No incoming proposals'**
  String get swapNoIncoming;

  /// No description provided for @swapIncomingHint.
  ///
  /// In en, this message translates to:
  /// **'Proposals will appear here'**
  String get swapIncomingHint;

  /// No description provided for @swapNoOutgoing.
  ///
  /// In en, this message translates to:
  /// **'No outgoing proposals'**
  String get swapNoOutgoing;

  /// No description provided for @swapOutgoingHint.
  ///
  /// In en, this message translates to:
  /// **'Start by finding a match!'**
  String get swapOutgoingHint;

  /// No description provided for @swapPriceOnRequest.
  ///
  /// In en, this message translates to:
  /// **'Price on request'**
  String get swapPriceOnRequest;

  /// No description provided for @swapMyServiceMessage.
  ///
  /// In en, this message translates to:
  /// **'This is your service. Manage it from My Services.'**
  String get swapMyServiceMessage;

  /// No description provided for @swapUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get swapUntitled;

  /// No description provided for @swapDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get swapDecline;

  /// No description provided for @swapYoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get swapYoursLabel;

  /// No description provided for @swapYourServiceBadge.
  ///
  /// In en, this message translates to:
  /// **'Your Service'**
  String get swapYourServiceBadge;

  /// No description provided for @bookingsMyBookings.
  ///
  /// In en, this message translates to:
  /// **'My Bookings'**
  String get bookingsMyBookings;

  /// No description provided for @bookingsClientRequests.
  ///
  /// In en, this message translates to:
  /// **'Client Requests'**
  String get bookingsClientRequests;

  /// No description provided for @bookingsMySwaps.
  ///
  /// In en, this message translates to:
  /// **'My Swaps'**
  String get bookingsMySwaps;

  /// No description provided for @bookingsNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No service booked yet.'**
  String get bookingsNoneYet;

  /// No description provided for @bookingsFilterOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get bookingsFilterOngoing;

  /// No description provided for @bookingsFilterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get bookingsFilterCompleted;

  /// No description provided for @bookingsFilterUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get bookingsFilterUpcoming;

  /// No description provided for @bookingsNoRequestsYet.
  ///
  /// In en, this message translates to:
  /// **'No requests received yet.'**
  String get bookingsNoRequestsYet;

  /// No description provided for @bookingsProviderFallback.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get bookingsProviderFallback;

  /// No description provided for @bookingsClientFallback.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get bookingsClientFallback;

  /// No description provided for @bookingsUpcomingDue.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Due'**
  String get bookingsUpcomingDue;

  /// No description provided for @bookingsWaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting Approval'**
  String get bookingsWaitingApproval;

  /// No description provided for @bookingsSkillSwap.
  ///
  /// In en, this message translates to:
  /// **'Skill Swap'**
  String get bookingsSkillSwap;

  /// No description provided for @bookingsMessageForDetails.
  ///
  /// In en, this message translates to:
  /// **'Message provider for details'**
  String get bookingsMessageForDetails;

  /// No description provided for @bookingsTrackStatus.
  ///
  /// In en, this message translates to:
  /// **'Track Status'**
  String get bookingsTrackStatus;

  /// No description provided for @bookingsReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get bookingsReject;

  /// No description provided for @bookingsAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get bookingsAccept;

  /// No description provided for @bookingsRequestAccepted.
  ///
  /// In en, this message translates to:
  /// **'Request Accepted! Client notified.'**
  String get bookingsRequestAccepted;

  /// No description provided for @bookingsRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Request Rejected.'**
  String get bookingsRequestRejected;

  /// No description provided for @bookingsOverdue.
  ///
  /// In en, this message translates to:
  /// **'OVERDUE'**
  String get bookingsOverdue;

  /// No description provided for @bookingsActiveAndPastSwaps.
  ///
  /// In en, this message translates to:
  /// **'Active & Past Swaps'**
  String get bookingsActiveAndPastSwaps;

  /// No description provided for @bookingsPendingSwap.
  ///
  /// In en, this message translates to:
  /// **'{count} Pending Swap Proposal'**
  String bookingsPendingSwap(int count);

  /// No description provided for @bookingsPendingSwaps.
  ///
  /// In en, this message translates to:
  /// **'{count} Pending Swap Proposals'**
  String bookingsPendingSwaps(int count);

  /// No description provided for @bookingsTapToView.
  ///
  /// In en, this message translates to:
  /// **'Tap to view and respond'**
  String get bookingsTapToView;

  /// No description provided for @bookingsTapToViewSent.
  ///
  /// In en, this message translates to:
  /// **'Tap to view your sent proposals'**
  String get bookingsTapToViewSent;

  /// No description provided for @bookingsServiceFallback.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get bookingsServiceFallback;

  /// No description provided for @bookingsPartnerFallback.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get bookingsPartnerFallback;

  /// No description provided for @bookingsSwapActive.
  ///
  /// In en, this message translates to:
  /// **'Swap Active'**
  String get bookingsSwapActive;

  /// No description provided for @bookingsAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Awaiting'**
  String get bookingsAwaiting;

  /// No description provided for @bookingsSwapBadge.
  ///
  /// In en, this message translates to:
  /// **'SWAP'**
  String get bookingsSwapBadge;

  /// No description provided for @bookingsMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get bookingsMessage;

  /// No description provided for @bookingsMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark Done'**
  String get bookingsMarkDone;

  /// No description provided for @bookingsNoSwapsYet.
  ///
  /// In en, this message translates to:
  /// **'No Swaps Yet'**
  String get bookingsNoSwapsYet;

  /// No description provided for @bookingsBrowseSwapBoard.
  ///
  /// In en, this message translates to:
  /// **'Browse Swap Board'**
  String get bookingsBrowseSwapBoard;

  /// No description provided for @aiGraciaGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello! I\'m Gracia, your LifeKit assistant — here to help you discover services, find your community, and make the most of your day. What can I do for you?'**
  String get aiGraciaGreeting;

  /// No description provided for @aiAlwaysHereForYou.
  ///
  /// In en, this message translates to:
  /// **'Always here for you'**
  String get aiAlwaysHereForYou;

  /// No description provided for @aiMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message Gracia…'**
  String get aiMessageHint;

  /// No description provided for @aiGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get aiGenericError;

  /// No description provided for @aiFallbackReply.
  ///
  /// In en, this message translates to:
  /// **'Sorry, I could not get a response.'**
  String get aiFallbackReply;

  /// No description provided for @aiProFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro Feature'**
  String get aiProFeatureTitle;

  /// No description provided for @aiProFeatureBody.
  ///
  /// In en, this message translates to:
  /// **'Gracia is available on Pro and Business plans. Upgrade to unlock AI chat, smart recommendations, and more.'**
  String get aiProFeatureBody;

  /// No description provided for @aiMaybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get aiMaybeLater;

  /// No description provided for @aiUpgradeNow.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Now ⚡'**
  String get aiUpgradeNow;

  /// No description provided for @aiActionViewFallback.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get aiActionViewFallback;

  /// No description provided for @walletLoadingWallet.
  ///
  /// In en, this message translates to:
  /// **'Loading wallet...'**
  String get walletLoadingWallet;

  /// No description provided for @walletAccountUsage.
  ///
  /// In en, this message translates to:
  /// **'Account Usage'**
  String get walletAccountUsage;

  /// No description provided for @walletLoadingUsage.
  ///
  /// In en, this message translates to:
  /// **'Loading usage...'**
  String get walletLoadingUsage;

  /// No description provided for @walletSlotsUsedUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Slots Used: {count}/∞ (Includes Drafts & Pending)'**
  String walletSlotsUsedUnlimited(int count);

  /// No description provided for @walletSlotsUsedLimited.
  ///
  /// In en, this message translates to:
  /// **'Slots Used: {count}/{limit} (Includes Drafts & Pending)'**
  String walletSlotsUsedLimited(int count, int limit);

  /// No description provided for @walletRenewsInDays.
  ///
  /// In en, this message translates to:
  /// **'Renews in {days} days'**
  String walletRenewsInDays(int days);

  /// No description provided for @walletUpgradePlan.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Plan'**
  String get walletUpgradePlan;

  /// No description provided for @trialBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Launch Offer: Pro Trial Active'**
  String get trialBannerTitle;

  /// No description provided for @trialBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Renews in {days} days • Ends {date}'**
  String trialBannerSubtitle(int days, String date);

  /// No description provided for @trialPerkServices.
  ///
  /// In en, this message translates to:
  /// **'✔ 5 Services'**
  String get trialPerkServices;

  /// No description provided for @trialPerkCommission.
  ///
  /// In en, this message translates to:
  /// **'✔ 3% Commission'**
  String get trialPerkCommission;

  /// No description provided for @trialPerkAI.
  ///
  /// In en, this message translates to:
  /// **'✔ Pro AI'**
  String get trialPerkAI;

  /// No description provided for @subscriptionPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription Plans'**
  String get subscriptionPlansTitle;

  /// No description provided for @subscriptionGoPremium.
  ///
  /// In en, this message translates to:
  /// **'Go Premium'**
  String get subscriptionGoPremium;

  /// No description provided for @subscriptionGoPremiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock more services, more communities, and faster growth.'**
  String get subscriptionGoPremiumSubtitle;

  /// No description provided for @subscriptionPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get subscriptionPopular;

  /// No description provided for @subscriptionCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get subscriptionCurrentPlan;

  /// No description provided for @subscriptionFreePlan.
  ///
  /// In en, this message translates to:
  /// **'Free Plan'**
  String get subscriptionFreePlan;

  /// No description provided for @subscriptionPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{price}/mo'**
  String subscriptionPerMonth(String price);

  /// No description provided for @subscriptionActiveUntil.
  ///
  /// In en, this message translates to:
  /// **'Subscription active until {date}'**
  String subscriptionActiveUntil(String date);

  /// No description provided for @subscriptionInsufficientFundsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insufficient Funds'**
  String get subscriptionInsufficientFundsTitle;

  /// No description provided for @subscriptionInsufficientFundsBody.
  ///
  /// In en, this message translates to:
  /// **'Your wallet balance is too low for this purchase. Add money to continue.'**
  String get subscriptionInsufficientFundsBody;

  /// No description provided for @subscriptionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get subscriptionCancel;

  /// No description provided for @subscriptionAddMoney.
  ///
  /// In en, this message translates to:
  /// **'Add Money'**
  String get subscriptionAddMoney;

  /// No description provided for @planNameFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get planNameFree;

  /// No description provided for @planNamePlus.
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get planNamePlus;

  /// No description provided for @planNamePro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get planNamePro;

  /// No description provided for @planNameBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get planNameBusiness;

  /// No description provided for @planFreeFeature1.
  ///
  /// In en, this message translates to:
  /// **'0 services'**
  String get planFreeFeature1;

  /// No description provided for @planFreeFeature2.
  ///
  /// In en, this message translates to:
  /// **'Max 1 community'**
  String get planFreeFeature2;

  /// No description provided for @planFreeFeature3.
  ///
  /// In en, this message translates to:
  /// **'Basic visibility'**
  String get planFreeFeature3;

  /// No description provided for @planPlusFeature1.
  ///
  /// In en, this message translates to:
  /// **'1 service'**
  String get planPlusFeature1;

  /// No description provided for @planPlusFeature2.
  ///
  /// In en, this message translates to:
  /// **'Max 3 communities'**
  String get planPlusFeature2;

  /// No description provided for @planPlusFeature3.
  ///
  /// In en, this message translates to:
  /// **'Priority listing boost ready'**
  String get planPlusFeature3;

  /// No description provided for @planProFeature1.
  ///
  /// In en, this message translates to:
  /// **'5 services'**
  String get planProFeature1;

  /// No description provided for @planProFeature2.
  ///
  /// In en, this message translates to:
  /// **'Max 5 communities'**
  String get planProFeature2;

  /// No description provided for @planProFeature3.
  ///
  /// In en, this message translates to:
  /// **'Best for growing providers'**
  String get planProFeature3;

  /// No description provided for @planBusinessFeature1.
  ///
  /// In en, this message translates to:
  /// **'Unlimited services'**
  String get planBusinessFeature1;

  /// No description provided for @planBusinessFeature2.
  ///
  /// In en, this message translates to:
  /// **'Unlimited communities'**
  String get planBusinessFeature2;

  /// No description provided for @planBusinessFeature3.
  ///
  /// In en, this message translates to:
  /// **'Top-tier monetization access'**
  String get planBusinessFeature3;

  /// No description provided for @errNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get errNoInternet;

  /// No description provided for @errTimeout.
  ///
  /// In en, this message translates to:
  /// **'That took too long. Please try again.'**
  String get errTimeout;

  /// No description provided for @errWrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password. Please try again.'**
  String get errWrongCredentials;

  /// No description provided for @errEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Try signing in instead.'**
  String get errEmailTaken;

  /// No description provided for @errUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find an account with that email.'**
  String get errUserNotFound;

  /// No description provided for @errInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get errInvalidEmail;

  /// No description provided for @errWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Your password is too weak. Try something longer.'**
  String get errWeakPassword;

  /// No description provided for @errSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get errSessionExpired;

  /// No description provided for @errInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code is invalid or expired. Please request a new one.'**
  String get errInvalidCode;

  /// No description provided for @errInsufficientFunds.
  ///
  /// In en, this message translates to:
  /// **'Not enough money in your wallet. Top up and try again.'**
  String get errInsufficientFunds;

  /// No description provided for @errServer.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Please try again shortly.'**
  String get errServer;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errGeneric;

  /// No description provided for @confirmationSent.
  ///
  /// In en, this message translates to:
  /// **'Confirmation sent!'**
  String get confirmationSent;

  /// No description provided for @disputeSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Dispute submitted. Our team will review it.'**
  String get disputeSubmitted;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done!'**
  String get actionDone;

  /// No description provided for @signupPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a password'**
  String get signupPasswordTitle;

  /// No description provided for @signupPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick something secure — at least 6 characters'**
  String get signupPasswordSubtitle;

  /// No description provided for @errorConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password.'**
  String get errorConfirmPassword;

  /// No description provided for @signupAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'By creating an account you agree to our'**
  String get signupAgreePrefix;

  /// No description provided for @signupAgreeAnd.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get signupAgreeAnd;

  /// No description provided for @blockedUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedUsersTitle;

  /// No description provided for @blockedUsersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'People whose posts you\'ve hidden'**
  String get blockedUsersSubtitle;

  /// No description provided for @blockedUsersEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t blocked anyone'**
  String get blockedUsersEmpty;

  /// No description provided for @blockedUsersEmptySub.
  ///
  /// In en, this message translates to:
  /// **'When you block someone from a post, they\'ll show up here.'**
  String get blockedUsersEmptySub;

  /// No description provided for @blockedUserFallbackName.
  ///
  /// In en, this message translates to:
  /// **'LifeKit user'**
  String get blockedUserFallbackName;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @userUnblocked.
  ///
  /// In en, this message translates to:
  /// **'{name} unblocked'**
  String userUnblocked(String name);

  /// No description provided for @trackTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking details'**
  String get trackTitle;

  /// No description provided for @trackStepRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get trackStepRequested;

  /// No description provided for @trackStepRequestedSub.
  ///
  /// In en, this message translates to:
  /// **'Booking request sent'**
  String get trackStepRequestedSub;

  /// No description provided for @trackStepConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get trackStepConfirmed;

  /// No description provided for @trackStepConfirmedSub.
  ///
  /// In en, this message translates to:
  /// **'The provider accepted the booking'**
  String get trackStepConfirmedSub;

  /// No description provided for @trackStepConfirmedPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the provider to accept'**
  String get trackStepConfirmedPending;

  /// No description provided for @trackStepServiceDay.
  ///
  /// In en, this message translates to:
  /// **'Service day'**
  String get trackStepServiceDay;

  /// No description provided for @trackStepBothConfirm.
  ///
  /// In en, this message translates to:
  /// **'Both confirm'**
  String get trackStepBothConfirm;

  /// No description provided for @trackStepBothConfirmDone.
  ///
  /// In en, this message translates to:
  /// **'Both sides confirmed'**
  String get trackStepBothConfirmDone;

  /// No description provided for @trackStepWaitingYou.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your confirmation'**
  String get trackStepWaitingYou;

  /// No description provided for @trackStepWaitingOther.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name}'**
  String trackStepWaitingOther(String name);

  /// No description provided for @trackStepPaidOut.
  ///
  /// In en, this message translates to:
  /// **'Paid out'**
  String get trackStepPaidOut;

  /// No description provided for @trackStepPaidOutSub.
  ///
  /// In en, this message translates to:
  /// **'Funds released to the provider'**
  String get trackStepPaidOutSub;

  /// No description provided for @trackStepSwapDone.
  ///
  /// In en, this message translates to:
  /// **'Swap complete'**
  String get trackStepSwapDone;

  /// No description provided for @trackStepSwapDoneSub.
  ///
  /// In en, this message translates to:
  /// **'Both skills exchanged'**
  String get trackStepSwapDoneSub;

  /// No description provided for @trackHdrRequestedTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the provider'**
  String get trackHdrRequestedTitle;

  /// No description provided for @trackHdrRequestedSub.
  ///
  /// In en, this message translates to:
  /// **'They\'ll accept or decline your request soon. Your money is safely on hold.'**
  String get trackHdrRequestedSub;

  /// No description provided for @trackHdrNewRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'New booking request'**
  String get trackHdrNewRequestTitle;

  /// No description provided for @trackHdrNewRequestSub.
  ///
  /// In en, this message translates to:
  /// **'Accept or decline it from your Requests tab.'**
  String get trackHdrNewRequestSub;

  /// No description provided for @trackHdrUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get trackHdrUpcomingTitle;

  /// No description provided for @trackHdrUpcomingSub.
  ///
  /// In en, this message translates to:
  /// **'Everything is set for the service day.'**
  String get trackHdrUpcomingSub;

  /// No description provided for @trackHdrActionTitle.
  ///
  /// In en, this message translates to:
  /// **'Your confirmation is needed'**
  String get trackHdrActionTitle;

  /// No description provided for @trackHdrActionClientSub.
  ///
  /// In en, this message translates to:
  /// **'Confirm once you\'ve received the service so funds can be released.'**
  String get trackHdrActionClientSub;

  /// No description provided for @trackHdrActionProviderSub.
  ///
  /// In en, this message translates to:
  /// **'Mark the job done once you\'ve finished.'**
  String get trackHdrActionProviderSub;

  /// No description provided for @trackHdrWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name}'**
  String trackHdrWaitingTitle(String name);

  /// No description provided for @trackHdrWaitingSub.
  ///
  /// In en, this message translates to:
  /// **'You\'ve confirmed — we\'ll let you know when they do.'**
  String get trackHdrWaitingSub;

  /// No description provided for @trackHdrCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'All done!'**
  String get trackHdrCompletedTitle;

  /// No description provided for @trackHdrCompletedSub.
  ///
  /// In en, this message translates to:
  /// **'Funds have been released. Thanks for using LifeKit.'**
  String get trackHdrCompletedSub;

  /// No description provided for @trackHdrSwapCompletedSub.
  ///
  /// In en, this message translates to:
  /// **'Your skill swap is complete.'**
  String get trackHdrSwapCompletedSub;

  /// No description provided for @trackHdrOverdueTitle.
  ///
  /// In en, this message translates to:
  /// **'Past its scheduled time'**
  String get trackHdrOverdueTitle;

  /// No description provided for @trackHdrOverdueSub.
  ///
  /// In en, this message translates to:
  /// **'Please confirm the service was completed, or report an issue to keep the funds on hold.'**
  String get trackHdrOverdueSub;

  /// No description provided for @trackHdrDisputedTitle.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get trackHdrDisputedTitle;

  /// No description provided for @trackHdrDisputedSub.
  ///
  /// In en, this message translates to:
  /// **'Our team is reviewing this dispute. Funds stay on hold until it\'s resolved.'**
  String get trackHdrDisputedSub;

  /// No description provided for @trackHdrCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get trackHdrCancelledTitle;

  /// No description provided for @trackHdrCancelledSub.
  ///
  /// In en, this message translates to:
  /// **'This booking was cancelled. Any held funds were returned to the wallet.'**
  String get trackHdrCancelledSub;

  /// No description provided for @trackInDays.
  ///
  /// In en, this message translates to:
  /// **'in {d}d {h}h'**
  String trackInDays(int d, int h);

  /// No description provided for @trackInHours.
  ///
  /// In en, this message translates to:
  /// **'in {h}h {m}m'**
  String trackInHours(int h, int m);

  /// No description provided for @trackInMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {m} min'**
  String trackInMinutes(int m);

  /// No description provided for @trackEscrowTitle.
  ///
  /// In en, this message translates to:
  /// **'Action required'**
  String get trackEscrowTitle;

  /// No description provided for @trackEscrowBody.
  ///
  /// In en, this message translates to:
  /// **'The provider marked this job as done. If you don\'t confirm or report an issue, funds are released automatically in 48 hours.'**
  String get trackEscrowBody;

  /// No description provided for @trackMarkReceived.
  ///
  /// In en, this message translates to:
  /// **'Mark service received'**
  String get trackMarkReceived;

  /// No description provided for @trackMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark job done'**
  String get trackMarkDone;

  /// No description provided for @trackYouConfirmed.
  ///
  /// In en, this message translates to:
  /// **'You confirmed. Waiting for {name}…'**
  String trackYouConfirmed(String name);

  /// No description provided for @trackSwapInfo.
  ///
  /// In en, this message translates to:
  /// **'This is a skill swap — confirming marks it as successful.'**
  String get trackSwapInfo;

  /// No description provided for @trackEscrowInfo.
  ///
  /// In en, this message translates to:
  /// **'Funds stay safely on hold until both of you confirm.'**
  String get trackEscrowInfo;

  /// No description provided for @trackReportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report an issue'**
  String get trackReportIssue;

  /// No description provided for @trackRateProvider.
  ///
  /// In en, this message translates to:
  /// **'Rate the provider'**
  String get trackRateProvider;

  /// No description provided for @trackRateClient.
  ///
  /// In en, this message translates to:
  /// **'Rate the client'**
  String get trackRateClient;

  /// No description provided for @trackScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get trackScheduled;

  /// No description provided for @trackAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get trackAmount;

  /// No description provided for @trackWith.
  ///
  /// In en, this message translates to:
  /// **'With'**
  String get trackWith;

  /// No description provided for @trackSkillSwap.
  ///
  /// In en, this message translates to:
  /// **'Skill swap'**
  String get trackSkillSwap;

  /// No description provided for @trackFallbackProvider.
  ///
  /// In en, this message translates to:
  /// **'the provider'**
  String get trackFallbackProvider;

  /// No description provided for @trackFallbackClient.
  ///
  /// In en, this message translates to:
  /// **'the client'**
  String get trackFallbackClient;

  /// No description provided for @bookingsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get bookingsFilterAll;

  /// No description provided for @bookingsFilterEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here right now.'**
  String get bookingsFilterEmpty;

  /// No description provided for @bookingSuccessSub.
  ///
  /// In en, this message translates to:
  /// **'Your service is booked. The provider will confirm shortly — we\'ll keep you posted.'**
  String get bookingSuccessSub;

  /// No description provided for @viewMyBookings.
  ///
  /// In en, this message translates to:
  /// **'View my bookings'**
  String get viewMyBookings;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backToHome;

  /// No description provided for @obTitle1.
  ///
  /// In en, this message translates to:
  /// **'Offer your skills.\nEarn on your terms.'**
  String get obTitle1;

  /// No description provided for @obDesc1.
  ///
  /// In en, this message translates to:
  /// **'Turn your talent into income by offering your services to a community that values what you do.'**
  String get obDesc1;

  /// No description provided for @obTitle2.
  ///
  /// In en, this message translates to:
  /// **'Build a profile\npeople trust'**
  String get obTitle2;

  /// No description provided for @obDesc2.
  ///
  /// In en, this message translates to:
  /// **'Showcase your work and collect reviews, so clients book you with confidence.'**
  String get obDesc2;

  /// No description provided for @obTitle3.
  ///
  /// In en, this message translates to:
  /// **'Book trusted services,\nanytime, anywhere'**
  String get obTitle3;

  /// No description provided for @obDesc3.
  ///
  /// In en, this message translates to:
  /// **'From beauty to home repairs, wellness and personal care — reliable help near you, all in one app.'**
  String get obDesc3;

  /// No description provided for @obTitle4.
  ///
  /// In en, this message translates to:
  /// **'Where community\nmeets opportunity'**
  String get obTitle4;

  /// No description provided for @obDesc4.
  ///
  /// In en, this message translates to:
  /// **'Connect, swap skills and grow with people who get you.'**
  String get obDesc4;

  /// No description provided for @obHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get obHaveAccount;

  /// No description provided for @authNameHint.
  ///
  /// In en, this message translates to:
  /// **'Please include your last name too'**
  String get authNameHint;

  /// No description provided for @authNameBoth.
  ///
  /// In en, this message translates to:
  /// **'Please enter both your first and last name.'**
  String get authNameBoth;

  /// No description provided for @authStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String authStepOf(int current, int total);

  /// No description provided for @authPwWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get authPwWeak;

  /// No description provided for @authPwFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get authPwFair;

  /// No description provided for @authPwGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get authPwGood;

  /// No description provided for @authPwStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get authPwStrong;

  /// No description provided for @authPwTip.
  ///
  /// In en, this message translates to:
  /// **'Mix letters, numbers and a symbol for a stronger password.'**
  String get authPwTip;

  /// No description provided for @authVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get authVerifyTitle;

  /// No description provided for @authVerifySub.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code we sent to {email}'**
  String authVerifySub(String email);

  /// No description provided for @authResend.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get a code? Resend'**
  String get authResend;

  /// No description provided for @authResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String authResendIn(int seconds);

  /// No description provided for @authCodeSent.
  ///
  /// In en, this message translates to:
  /// **'New code sent! Check your inbox.'**
  String get authCodeSent;

  /// No description provided for @authResendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t resend the code. Please try again.'**
  String get authResendFailed;

  /// No description provided for @authCheckSpam.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find it? Check your spam folder.'**
  String get authCheckSpam;

  /// No description provided for @authAlmostTitle.
  ///
  /// In en, this message translates to:
  /// **'Almost done!'**
  String get authAlmostTitle;

  /// No description provided for @authAlmostSub.
  ///
  /// In en, this message translates to:
  /// **'Add a profile picture — you can always do this later'**
  String get authAlmostSub;

  /// No description provided for @authAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get authAddPhoto;

  /// No description provided for @authChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get authChangePhoto;

  /// No description provided for @authSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get authSkipForNow;

  /// No description provided for @authWelcomeAboard.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set! Welcome to LifeKit 🎉'**
  String get authWelcomeAboard;

  /// No description provided for @authPhotoSkipped.
  ///
  /// In en, this message translates to:
  /// **'Profile picture skipped — you can add it later.'**
  String get authPhotoSkipped;

  /// No description provided for @authSocialFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get authSocialFailed;

  /// No description provided for @aiNewChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get aiNewChat;

  /// No description provided for @aiTryAsking.
  ///
  /// In en, this message translates to:
  /// **'Try asking'**
  String get aiTryAsking;

  /// No description provided for @aiSuggest1.
  ///
  /// In en, this message translates to:
  /// **'Find me a cleaner this weekend'**
  String get aiSuggest1;

  /// No description provided for @aiSuggest2.
  ///
  /// In en, this message translates to:
  /// **'How can I earn with my skills?'**
  String get aiSuggest2;

  /// No description provided for @aiSuggest3.
  ///
  /// In en, this message translates to:
  /// **'How do skill swaps work?'**
  String get aiSuggest3;

  /// No description provided for @aiSuggest4.
  ///
  /// In en, this message translates to:
  /// **'Which communities should I join?'**
  String get aiSuggest4;

  /// No description provided for @aiTapRetry.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Tap to retry'**
  String get aiTapRetry;

  /// No description provided for @aiCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get aiCopied;

  /// No description provided for @aiFreeBanner.
  ///
  /// In en, this message translates to:
  /// **'Chatting with Gracia is a Pro feature. Start your free trial or upgrade to unlock it.'**
  String get aiFreeBanner;

  /// No description provided for @aiSeePlans.
  ///
  /// In en, this message translates to:
  /// **'See plans'**
  String get aiSeePlans;

  /// No description provided for @aiCardService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get aiCardService;

  /// No description provided for @aiCardCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get aiCardCommunity;

  /// No description provided for @aiCardEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get aiCardEvent;

  /// No description provided for @aiNewChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Start a new chat? This clears the current conversation.'**
  String get aiNewChatConfirm;

  /// No description provided for @aiObTitle.
  ///
  /// In en, this message translates to:
  /// **'AI setup guide'**
  String get aiObTitle;

  /// No description provided for @aiObAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Gracia is building your plan…'**
  String get aiObAnalyzing;

  /// No description provided for @aiObHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Let AI guide your\nLifeKit journey'**
  String get aiObHeroTitle;

  /// No description provided for @aiObHeroSub.
  ///
  /// In en, this message translates to:
  /// **'Get a personalised 7-day success plan in seconds.'**
  String get aiObHeroSub;

  /// No description provided for @aiObGoals.
  ///
  /// In en, this message translates to:
  /// **'Your goals'**
  String get aiObGoals;

  /// No description provided for @aiObGoalsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Earn extra income on weekends'**
  String get aiObGoalsHint;

  /// No description provided for @aiObSkills.
  ///
  /// In en, this message translates to:
  /// **'Your skills'**
  String get aiObSkills;

  /// No description provided for @aiObSkillsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Cooking, tutoring maths'**
  String get aiObSkillsHint;

  /// No description provided for @aiObInterests.
  ///
  /// In en, this message translates to:
  /// **'Your interests'**
  String get aiObInterests;

  /// No description provided for @aiObInterestsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Music, fitness, meeting people'**
  String get aiObInterestsHint;

  /// No description provided for @aiObGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate my 7-day plan'**
  String get aiObGenerate;

  /// No description provided for @aiObFillAll.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all three fields.'**
  String get aiObFillAll;

  /// No description provided for @aiObPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Your personalised\n7-day plan'**
  String get aiObPlanTitle;

  /// No description provided for @aiObPlanSub.
  ///
  /// In en, this message translates to:
  /// **'Follow these steps to hit the ground running!'**
  String get aiObPlanSub;

  /// No description provided for @aiObFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish & go to home'**
  String get aiObFinish;

  /// No description provided for @aiObDay.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String aiObDay(int day);

  /// No description provided for @aiObTakeAction.
  ///
  /// In en, this message translates to:
  /// **'Take action'**
  String get aiObTakeAction;

  /// No description provided for @aiAutofillDone.
  ///
  /// In en, this message translates to:
  /// **'✨ AI filled in your service! Now pick a category and add photos.'**
  String get aiAutofillDone;

  /// No description provided for @planDayOf.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {total}'**
  String planDayOf(int day, int total);

  /// No description provided for @planDoIt.
  ///
  /// In en, this message translates to:
  /// **'Do it'**
  String get planDoIt;

  /// No description provided for @planUndo.
  ///
  /// In en, this message translates to:
  /// **'Mark not done'**
  String get planUndo;

  /// No description provided for @planCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up! Your next task unlocks tomorrow.'**
  String get planCaughtUp;

  /// No description provided for @planProgress.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} done'**
  String planProgress(int done, int total);

  /// No description provided for @planCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan complete! 🎉'**
  String get planCompleteTitle;

  /// No description provided for @planCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'You finished all 7 days of your LifeKit plan. What a start!'**
  String get planCompleteBody;

  /// No description provided for @planSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Your 7-day plan'**
  String get planSheetTitle;

  /// No description provided for @planToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get planToday;

  /// No description provided for @planDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get planDone;

  /// No description provided for @planLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get planLocked;

  /// No description provided for @planCatchUp.
  ///
  /// In en, this message translates to:
  /// **'Catch up'**
  String get planCatchUp;

  /// No description provided for @planViewAll.
  ///
  /// In en, this message translates to:
  /// **'View plan'**
  String get planViewAll;

  /// No description provided for @planDayDoneToast.
  ///
  /// In en, this message translates to:
  /// **'Day {day} done — nice work!'**
  String planDayDoneToast(int day);

  /// No description provided for @msgReceiptDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Receipt saved to your files'**
  String get msgReceiptDownloaded;

  /// No description provided for @msgEnterReason.
  ///
  /// In en, this message translates to:
  /// **'Please enter a reason.'**
  String get msgEnterReason;

  /// No description provided for @msgPostReported.
  ///
  /// In en, this message translates to:
  /// **'Post reported. Thank you.'**
  String get msgPostReported;

  /// No description provided for @msgServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service details unavailable.'**
  String get msgServiceUnavailable;

  /// No description provided for @reportScam.
  ///
  /// In en, this message translates to:
  /// **'Scam or fraud'**
  String get reportScam;

  /// No description provided for @reportHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get reportHarassment;

  /// No description provided for @reportInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get reportInappropriate;

  /// No description provided for @reportOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportOther;

  /// No description provided for @placesNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get placesNearby;

  /// No description provided for @placesPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get placesPopular;

  /// No description provided for @msgProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated!'**
  String get msgProfileUpdated;

  /// No description provided for @msgProfileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your profile'**
  String get msgProfileLoadFailed;

  /// No description provided for @msgLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied!'**
  String get msgLinkCopied;

  /// No description provided for @shareScanToConnect.
  ///
  /// In en, this message translates to:
  /// **'Scan to connect with this user on LifeKit'**
  String get shareScanToConnect;

  /// No description provided for @msgServiceDeleted.
  ///
  /// In en, this message translates to:
  /// **'Service deleted.'**
  String get msgServiceDeleted;

  /// No description provided for @msgBoostActivated.
  ///
  /// In en, this message translates to:
  /// **'Boost activated!'**
  String get msgBoostActivated;

  /// No description provided for @msgFoundInParent.
  ///
  /// In en, this message translates to:
  /// **'Found in “{parent}”. Opening…'**
  String msgFoundInParent(String parent);

  /// No description provided for @msgRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent!'**
  String get msgRequestSent;

  /// No description provided for @msgReviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted — thank you!'**
  String get msgReviewSubmitted;

  /// No description provided for @sortTopRated.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get sortTopRated;

  /// No description provided for @sortPriceLowHigh.
  ///
  /// In en, this message translates to:
  /// **'Price: low to high'**
  String get sortPriceLowHigh;

  /// No description provided for @msgNoServicesFound.
  ///
  /// In en, this message translates to:
  /// **'No services found.'**
  String get msgNoServicesFound;

  /// No description provided for @msgProposalFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t write a proposal. Please try again.'**
  String get msgProposalFailed;

  /// No description provided for @msgEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount'**
  String get msgEnterAmount;

  /// No description provided for @msgMinDeposit.
  ///
  /// In en, this message translates to:
  /// **'The minimum deposit is \$5'**
  String get msgMinDeposit;

  /// No description provided for @msgWalletFunded.
  ///
  /// In en, this message translates to:
  /// **'Wallet funded successfully!'**
  String get msgWalletFunded;
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
      <String>['en', 'ka', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ka':
      return AppLocalizationsKa();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
