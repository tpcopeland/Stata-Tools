import sys
sys.path.insert(0, ".")
from stata_interpreter.interpreter import StataInterpreter

interp = StataInterpreter()

# Set up macros like they would be after syntax parsing with empty dosecuts
interp.macros.set_local('dosecuts', '')
interp.macros.set_local('dose', '')

# The actual condition from the program
# if "`dosecuts'" != "" & "`dose'" == ""
test_condition = '"`dosecuts' + "'" + '" != "" & "`dose' + "'" + '" == ""'
print('Condition:', repr(test_condition))

expanded = interp.macros.expand(test_condition)
print('Expanded:', repr(expanded))

result = interp.expr_eval.evaluate(expanded, row_context=False)
print('Result:', result)
print('Type:', type(result))
