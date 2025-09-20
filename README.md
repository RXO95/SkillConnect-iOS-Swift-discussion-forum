SkillConnect

A modern, community-driven discussion forum built natively for iOS with SwiftUI. SkillConnect allows users to connect by sharing and rewarding knowledge through a unique "Skill Points" system, creating a reputation platform based on expertise.
  Features

    Full Authentication Flow: Secure user sign-up, login (with email or username), password reset, and session persistence.

    Dynamic Discussion Forum: Users can create posts, view a real-time feed of discussions, and engage with content in a modern, card-based UI.

    Interactive Commenting System: Add comments to any post to share insights and ask questions.

    Unique "Skill Points" System: Reward helpful comments with Skill Points, building a reputation system based on knowledge.

    Customizable User Profiles: Users can edit their username, bio, and upload a custom profile picture.

    Personalized Feeds: The profile page displays all posts made by that specific user.

    Advanced Theming: Choose between Light, Dark, System, and a custom Animated theme that applies across the entire app.

  Technology Stack

    UI: SwiftUI

    Language: Swift

    Backend: Firebase

        Authentication: For user management.

        Firestore: Real-time NoSQL database for posts, comments, and user profiles.

        Storage: For hosting user-uploaded profile pictures.

    Concurrency: Modern Swift Concurrency (async/await) for seamless background tasks and data fetching.

    Frameworks: Combine for reactive UI updates and state management.

  Setup & Installation

    To run this project, you'll need to set up your own Firebase backend.

    Clone the repository:

    git clone [https://github.com/](https://github.com/)[YOUR_USERNAME]/SkillConnect.git
    cd SkillConnect

    Create a Firebase Project:

        Go to the Firebase Console and create a new project.

        Add an iOS app to your project with the correct bundle identifier.

        In the Firebase console, enable Authentication (with the Email/Password provider), Firestore, and Storage.

    Add GoogleService-Info.plist:

        Download the GoogleService-Info.plist file from your Firebase project settings.

        Place this file in the root of the Xcode project folder (SkillConnect/).

        Important: This file is correctly excluded by the .gitignore and should never be committed to your repository.

    Open in Xcode and Run:

        Open the .xcodeproj file.

        Build and run the project on an iOS simulator or a physical device.
