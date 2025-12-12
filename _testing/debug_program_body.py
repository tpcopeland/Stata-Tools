import sys
sys.path.insert(0, ".")
from stata_interpreter.parser import StataParser, preprocess_stata_code

with open('tvtools/tvexpose.ado', 'r') as f:
    ado_content = f.read()

preprocessed = preprocess_stata_code(ado_content)
parser = StataParser()
commands = parser.parse_text(preprocessed)

# Find body_start
body_start = None
for idx, cmd in enumerate(commands):
    if cmd.command == 'program':
        body_start = idx + 1
        break

print(f'Total commands: {len(commands)}')
print(f'body_start: {body_start}')
print()

# Check commands at specific raw indices
print('Commands at raw indices 18-25:')
for i in range(18, 26):
    if i < len(commands):
        cmd = commands[i]
        print(f'  idx {i}: command={cmd.command!r:15} raw_line={cmd.raw_line[:50]!r}')
    else:
        print(f'  idx {i}: OUT OF RANGE')
