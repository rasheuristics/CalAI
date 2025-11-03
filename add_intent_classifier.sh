#!/bin/bash

# Script to add IntentClassifier.swift to Xcode project

PROJECT_FILE="/Users/btessema/Desktop/CalAI/CalAI/CalAI.xcodeproj/project.pbxproj"
NEW_FILE="CalAI/IntentClassifier.swift"

# Generate a unique ID for the file reference
FILE_REF_ID=$(uuidgen | tr -d '-' | cut -c1-24)
BUILD_FILE_ID=$(uuidgen | tr -d '-' | cut -c1-24)

echo "Adding IntentClassifier.swift to Xcode project..."
echo "File Reference ID: $FILE_REF_ID"
echo "Build File ID: $BUILD_FILE_ID"

# Backup the project file
cp "$PROJECT_FILE" "$PROJECT_FILE.backup-intent-classifier"

# Add file reference (find the CalAI group and add it there)
# We'll add it to the PBXFileReference section
sed -i '' "/\/\* CalAI \*\/ = {$/,/};/s/children = (/children = (\n\t\t\t\t${FILE_REF_ID} \/\* IntentClassifier.swift \*\/,/" "$PROJECT_FILE"

# Add the file reference definition
sed -i '' "/\/\* Begin PBXFileReference section \*\//a\\
\t\t${FILE_REF_ID} /* IntentClassifier.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = IntentClassifier.swift; sourceTree = \"<group>\"; };\\
" "$PROJECT_FILE"

# Add to PBXBuildFile section
sed -i '' "/\/\* Begin PBXBuildFile section \*\//a\\
\t\t${BUILD_FILE_ID} /* IntentClassifier.swift in Sources */ = {isa = PBXBuildFile; fileRef = ${FILE_REF_ID} /* IntentClassifier.swift */; };\\
" "$PROJECT_FILE"

# Add to PBXSourcesBuildPhase
sed -i '' "/\/\* Sources \*\/ = {$/,/};/s/files = (/files = (\n\t\t\t\t${BUILD_FILE_ID} \/\* IntentClassifier.swift in Sources \*\/,/" "$PROJECT_FILE"

echo "✅ IntentClassifier.swift added to Xcode project"
echo "Backup saved to: $PROJECT_FILE.backup-intent-classifier"
