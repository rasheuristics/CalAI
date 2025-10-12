#!/bin/bash

# Backup the project file
cp CalAI.xcodeproj/project.pbxproj CalAI.xcodeproj/project.pbxproj.backup

# Remove duplicate build file entries for old paths
sed -i '' '/CalAI\/AddEventView.swift in Sources.*fileRef = 50745D01/d' CalAI.xcodeproj/project.pbxproj
sed -i '' '/CalAI\/EditEventView.swift in Sources.*fileRef = 50745D02/d' CalAI.xcodeproj/project.pbxproj
sed -i '' '/CalAI\/Models\/MeetingPreparation.swift in Sources/d' CalAI.xcodeproj/project.pbxproj
sed -i '' '/CalAI\/Models\/MeetingFollowUp.swift in Sources/d' CalAI.xcodeproj/project.pbxproj
sed -i '' '/CalAI\/Views\/MeetingPreparationView.swift in Sources/d' CalAI.xcodeproj/project.pbxproj
sed -i '' '/CalAI\/Views\/MeetingFollowUpView.swift in Sources/d' CalAI.xcodeproj/project.pbxproj
sed -i '' '/PostMeetingService.swift in Sources.*fileRef = 7BA1D742/d' CalAI.xcodeproj/project.pbxproj
sed -i '' '/CrashReporter.swift in Sources.*fileRef = 506831E8/d' CalAI.xcodeproj/project.pbxproj
sed -i '' '/EventShareView.swift in Sources.*fileRef = 4B797E3A/d' CalAI.xcodeproj/project.pbxproj

echo "✅ Duplicates removed from project.pbxproj"
echo "Backup saved as: CalAI.xcodeproj/project.pbxproj.backup"
