---
title: Projects and GitHub
---

Hackatime creates projects from the project name sent by your editor plugin. By default, WakaTime-compatible plugins usually detect that name from version control or your editor workspace.

## Set a stable project name

Create a `.wakatime-project` file in the project root when automatic detection chooses the wrong name. Put the desired project name on the first line:

```text title=".wakatime-project"
hackatime
```

An empty file uses the folder name. An optional second line overrides the branch name. This file is different from a `.wakatime` file, which contains project-specific plugin settings.

Choose the name before accumulating substantial activity. Hackatime treats each distinct name as a separate project.

## Connect GitHub

Open [Projects](https://hackatime.hackclub.com/my/projects) and select **Sign in with GitHub**. Hackatime scans repositories available to your GitHub account and organisations, then matches unmapped projects by name.

Automatic matching links the repository to the coding project; it does not import GitHub activity or change your recorded coding time.

To correct a match:

1. Open [Projects](https://hackatime.hackclub.com/my/projects).
2. Select the edit action beside the project.
3. Enter a GitHub repository URL that your connected account can access.

Hackatime currently supports GitHub repository links only. Private repositories remain subject to GitHub access checks.

## Share or archive a project

Sharing creates a link-visible project statistics page. Anyone with that link may see the project statistics, so review the project name and data before enabling it.

Archiving removes a project from normal project lists and most statistics without deleting its heartbeats. You can switch to archived projects and restore it later.
