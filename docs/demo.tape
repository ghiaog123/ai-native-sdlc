# Records docs/demo.gif with https://github.com/charmbracelet/vhs
#
#   export GATE="$PWD/plugins/ai-sdlc/hooks/artifact-gate.sh"
#   vhs docs/demo.tape
#
# Only the scenario is staged, by docs/demo-setup.sh. The gate runs for real and
# its output is whatever the hook prints.

Output docs/demo.gif

Set Shell bash
Set FontSize 19
Set Width 1180
Set Height 700
Set Padding 24
Set Theme "Catppuccin Mocha"
Set TypingSpeed 26ms

# vhs 0.12 still records a Hide block, so the scenario is built on one visible line
# and the screen is cleared before the demo proper starts.
Type `export PS1='$ ' && source docs/demo-setup.sh && clear` Enter
Sleep 1.6s

Type `# A typo fix. No intent.md, no spec.md -- it entered at Build.` Enter
Sleep 300ms
Type `cat .sdlc/typo-fix/plan.md` Enter
Sleep 3.5s

Type `# The agent edits the README. The gate lets it through.` Enter
Sleep 300ms
Type `gate README.md` Enter
Sleep 2.2s

Type `# Now it reaches for the file that defines what it may touch.` Enter
Sleep 300ms
Type `gate REVIEW.md` Enter
Sleep 4.5s

Type `# A person called this change low-risk. The gate decides what that buys.` Enter
Sleep 3.5s
