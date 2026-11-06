#!/usr/bin/env bash
# You ONLY need to run this if instructed to by Hack Club's Fraud Department.

os=$(uname)
case "$os" in
  Darwin) base_dir="$HOME/Library/Caches/JetBrains" ;;
  Linux)  base_dir="${XDG_CACHE_HOME:-$HOME/.cache}/JetBrains" ;;
  *)
    echo "Unsupported operating system."
    exit 1
    ;;
esac

if [ ! -d "$base_dir" ]; then
  echo "No JetBrains data found. Open your IDE once and try again."
  exit 1
fi

ide_names=()
for dir in "$base_dir"/*/; do
  [ -d "$dir" ] && ide_names+=("$(basename "$dir")")
done

if (( ${#ide_names[@]} == 0 )); then
  echo "No IDE versions found."
  exit 1
fi

if ! command -v zip >/dev/null; then
  echo "ZIP utility missing. Please install zip and try again."
  exit 1
fi

echo "Choose your IDE/version:"
PS3="Enter number: "

select ide in "${ide_names[@]}"; do
  if [ -z "$ide" ]; then
    echo "Invalid number. Try again."
    continue
  fi

  ide_dir="$base_dir/$ide"

  if [ ! -d "$ide_dir/LocalHistory" ]; then
    echo "No Local History found for $ide. Try another version."
    continue
  fi

  to_zip=(LocalHistory)
  if [ -d "$ide_dir/caches" ]; then
    to_zip+=(caches)
  else
    echo "Caches missing. Exporting Local History only."
  fi

  out_dir="$HOME/Desktop"
  if [ "$os" = Linux ] && command -v xdg-user-dir >/dev/null; then
    xdg_desktop=$(xdg-user-dir DESKTOP 2>/dev/null)
    [ -d "$xdg_desktop" ] && out_dir="$xdg_desktop"
  fi
  [ -d "$out_dir" ] || out_dir="$HOME"

  zip_path="$out_dir/jetbrains-history-$ide-$(date +%Y%m%d-%H%M%S)-$$.zip"

  echo "Creating ZIP, please wait..."
  if (cd "$ide_dir" && zip -qr "$zip_path" "${to_zip[@]}") && [ -s "$zip_path" ]; then
    echo "Done! Drag the ZIP into this Slack thread: $zip_path"

    if [ "$os" = Darwin ]; then
      open -R "$zip_path"
    elif command -v xdg-open >/dev/null; then
      xdg-open "$out_dir" >/dev/null 2>&1 &
    fi
  else
    echo "ZIP creation failed. Check your available disk space and permissions."
  fi

  break
done
