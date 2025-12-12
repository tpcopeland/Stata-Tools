"""
Stata Parser - Tokenizer and command parser for Stata syntax.

Handles:
- Comments (*, //, /* */)
- String literals (single, double, compound quotes)
- Macro references (`local' and $global)
- Command parsing with if/in qualifiers and options
- Line continuation (///)
"""

import re
from dataclasses import dataclass, field
from typing import Optional, Any
from enum import Enum, auto


class TokenType(Enum):
    """Token types for Stata lexer."""

    # Literals
    NUMBER = auto()
    STRING = auto()
    NAME = auto()  # Variable names, command names, etc.

    # Operators
    PLUS = auto()
    MINUS = auto()
    STAR = auto()
    SLASH = auto()
    CARET = auto()
    EQUAL = auto()
    DOUBLE_EQUAL = auto()
    NOT_EQUAL = auto()
    LESS = auto()
    LESS_EQUAL = auto()
    GREATER = auto()
    GREATER_EQUAL = auto()
    AMPERSAND = auto()
    PIPE = auto()
    BANG = auto()
    TILDE = auto()

    # Delimiters
    LPAREN = auto()
    RPAREN = auto()
    LBRACKET = auto()
    RBRACKET = auto()
    LBRACE = auto()
    RBRACE = auto()
    COMMA = auto()
    COLON = auto()
    SEMICOLON = auto()

    # Special
    MACRO_LOCAL = auto()  # `name'
    MACRO_GLOBAL = auto()  # $name or ${name}
    MACRO_SCALAR = auto()  # `=expr'
    IF = auto()  # if qualifier
    IN = auto()  # in qualifier
    USING = auto()  # using clause
    NEWLINE = auto()
    EOF = auto()
    DOT = auto()  # . (for filenames, etc.)

    # Keywords
    KEYWORD = auto()


@dataclass
class Token:
    """A token from the Stata lexer."""

    type: TokenType
    value: Any
    line: int
    column: int


@dataclass
class ParsedCommand:
    """A parsed Stata command."""

    command: str = ""  # Command name
    prefix: Optional[str] = None  # by:, bysort:, quietly:, etc.
    prefix_vars: list = field(default_factory=list)  # Variables in by/bysort prefix
    prefix_sort_vars: list = field(
        default_factory=list
    )  # Sort vars in bysort (in parens)
    arguments: list = field(default_factory=list)  # Main arguments (varlist, etc.)
    if_condition: Optional[str] = None  # if qualifier
    in_range: Optional[tuple] = None  # in qualifier (start, end)
    using: Optional[str] = None  # using clause
    options: dict = field(default_factory=dict)  # Options after comma
    weight: Optional[tuple] = None  # Weight specification (type, var)
    raw_line: str = ""  # Original line for debugging


class StataLexer:
    """Tokenizer for Stata code."""

    KEYWORDS = {
        "if",
        "in",
        "using",
        "by",
        "bysort",
        "quietly",
        "noisily",
        "capture",
        "local",
        "global",
        "foreach",
        "forvalues",
        "while",
        "else",
        "program",
        "end",
        "version",
        "set",
        "return",
        "ereturn",
        "sreturn",
        "scalar",
        "matrix",
        "tempvar",
        "tempfile",
        "tempname",
        "preserve",
        "restore",
        "quietly",
        "qui",
        "cap",
        "capt",
        "capture",
    }

    def __init__(self, text: str):
        self.text = text
        self.pos = 0
        self.line = 1
        self.column = 1
        self.tokens: list[Token] = []

    def peek(self, offset: int = 0) -> str:
        """Look at character at current position + offset."""
        pos = self.pos + offset
        if pos >= len(self.text):
            return ""
        return self.text[pos]

    def advance(self) -> str:
        """Move to next character and return current."""
        char = self.peek()
        self.pos += 1
        if char == "\n":
            self.line += 1
            self.column = 1
        else:
            self.column += 1
        return char

    def skip_whitespace(self) -> None:
        """Skip whitespace except newlines."""
        while self.peek() in " \t\r":
            self.advance()

    def skip_line_continuation(self) -> bool:
        """Skip /// line continuation."""
        if self.text[self.pos : self.pos + 3] == "///":
            # Skip to end of line
            while self.peek() and self.peek() != "\n":
                self.advance()
            if self.peek() == "\n":
                self.advance()
            return True
        return False

    def skip_comment(self) -> bool:
        """Skip comments. Returns True if a comment was skipped."""
        # Line comment starting with * at beginning of command
        if self.peek() == "*" and (self.column == 1 or self.tokens == []):
            while self.peek() and self.peek() != "\n":
                self.advance()
            return True

        # Line comment with //
        if self.text[self.pos : self.pos + 2] == "//":
            # Check for line continuation ///
            if self.text[self.pos : self.pos + 3] == "///":
                return False  # Not a comment, handle as continuation
            while self.peek() and self.peek() != "\n":
                self.advance()
            return True

        # Block comment /* */
        if self.text[self.pos : self.pos + 2] == "/*":
            self.advance()  # skip /
            self.advance()  # skip *
            while self.pos < len(self.text):
                if self.text[self.pos : self.pos + 2] == "*/":
                    self.advance()
                    self.advance()
                    return True
                self.advance()
            return True

        return False

    def read_string(self, quote_char: str) -> str:
        """Read a string literal."""
        self.advance()  # skip opening quote
        result = []

        # Check for compound quotes `"..."'
        if quote_char == "`" and self.peek() == '"':
            self.advance()  # skip "
            while self.pos < len(self.text):
                if self.text[self.pos : self.pos + 2] == '"\'':
                    self.advance()  # skip "
                    self.advance()  # skip '
                    return "".join(result)
                result.append(self.advance())
            return "".join(result)

        # Regular string - handle nested macro references with quotes
        while self.peek() and self.peek() != quote_char:
            if self.peek() == "\\" and self.peek(1) == quote_char:
                self.advance()  # skip backslash
                result.append(self.advance())
            elif self.peek() == "`":
                # Nested macro reference - read until matching apostrophe
                # This handles `name' and `=expr' which may contain quotes
                result.append(self.advance())  # add backtick
                depth = 1
                while self.peek() and depth > 0:
                    ch = self.peek()
                    result.append(self.advance())
                    if ch == "`":
                        depth += 1
                    elif ch == "'":
                        depth -= 1
            else:
                result.append(self.advance())

        if self.peek() == quote_char:
            self.advance()  # skip closing quote

        return "".join(result)

    def read_macro_local(self) -> Token:
        """Read a local macro reference `name'."""
        start_line = self.line
        start_col = self.column
        self.advance()  # skip `

        # Check for scalar evaluation `=expr'
        if self.peek() == "=":
            self.advance()  # skip =
            # Read until closing '
            expr = []
            depth = 1
            while self.peek() and depth > 0:
                if self.peek() == "`":
                    depth += 1
                elif self.peek() == "'":
                    depth -= 1
                    if depth == 0:
                        break
                expr.append(self.advance())
            if self.peek() == "'":
                self.advance()
            return Token(TokenType.MACRO_SCALAR, "".join(expr), start_line, start_col)

        # Regular local macro
        name = []
        while self.peek() and self.peek() != "'":
            name.append(self.advance())

        if self.peek() == "'":
            self.advance()  # skip closing '

        return Token(TokenType.MACRO_LOCAL, "".join(name), start_line, start_col)

    def read_macro_global(self) -> Token:
        """Read a global macro reference $name or ${name}."""
        start_line = self.line
        start_col = self.column
        self.advance()  # skip $

        if self.peek() == "{":
            self.advance()  # skip {
            name = []
            while self.peek() and self.peek() != "}":
                name.append(self.advance())
            if self.peek() == "}":
                self.advance()
            return Token(TokenType.MACRO_GLOBAL, "".join(name), start_line, start_col)

        # Simple $name
        name = []
        while self.peek() and (self.peek().isalnum() or self.peek() == "_"):
            name.append(self.advance())

        return Token(TokenType.MACRO_GLOBAL, "".join(name), start_line, start_col)

    def read_number(self) -> Token:
        """Read a numeric literal."""
        start_line = self.line
        start_col = self.column
        result = []

        # Handle negative numbers
        if self.peek() == "-":
            result.append(self.advance())

        # Integer part
        while self.peek() and self.peek().isdigit():
            result.append(self.advance())

        # Decimal part
        if self.peek() == "." and self.peek(1).isdigit():
            result.append(self.advance())  # .
            while self.peek() and self.peek().isdigit():
                result.append(self.advance())

        # Exponent
        if self.peek() in "eE":
            result.append(self.advance())
            if self.peek() in "+-":
                result.append(self.advance())
            while self.peek() and self.peek().isdigit():
                result.append(self.advance())

        value = "".join(result)
        return Token(
            TokenType.NUMBER,
            float(value) if "." in value or "e" in value.lower() else int(value),
            start_line,
            start_col,
        )

    def read_name(self) -> Token:
        """Read a name (identifier)."""
        start_line = self.line
        start_col = self.column
        result = []

        # Names can start with letter or underscore
        while self.peek() and (self.peek().isalnum() or self.peek() in "_"):
            result.append(self.advance())

        name = "".join(result)
        token_type = TokenType.KEYWORD if name.lower() in self.KEYWORDS else TokenType.NAME
        return Token(token_type, name, start_line, start_col)

    def tokenize(self) -> list[Token]:
        """Tokenize the entire input."""
        self.tokens = []

        while self.pos < len(self.text):
            # Handle line continuation first
            if self.skip_line_continuation():
                continue

            # Skip whitespace
            self.skip_whitespace()

            if self.pos >= len(self.text):
                break

            # Skip comments
            if self.skip_comment():
                continue

            char = self.peek()
            start_line = self.line
            start_col = self.column

            # Newline
            if char == "\n":
                self.tokens.append(Token(TokenType.NEWLINE, "\n", start_line, start_col))
                self.advance()
                continue

            # String literals
            if char == '"':
                value = self.read_string('"')
                self.tokens.append(Token(TokenType.STRING, value, start_line, start_col))
                continue

            # Local macro or compound quote
            if char == "`":
                if self.peek(1) == '"':
                    # Compound quote `"..."'
                    value = self.read_string("`")
                    self.tokens.append(
                        Token(TokenType.STRING, value, start_line, start_col)
                    )
                else:
                    self.tokens.append(self.read_macro_local())
                continue

            # Global macro
            if char == "$":
                self.tokens.append(self.read_macro_global())
                continue

            # Numbers
            if char.isdigit() or (char == "." and self.peek(1).isdigit()):
                self.tokens.append(self.read_number())
                continue

            # Negative number (context-dependent)
            if char == "-" and self.peek(1).isdigit():
                # Check if this should be a number vs minus operator
                if not self.tokens or self.tokens[-1].type in {
                    TokenType.LPAREN,
                    TokenType.COMMA,
                    TokenType.EQUAL,
                    TokenType.NEWLINE,
                }:
                    self.tokens.append(self.read_number())
                    continue

            # Names/identifiers
            if char.isalpha() or char == "_":
                self.tokens.append(self.read_name())
                continue

            # Two-character operators
            two_char = self.text[self.pos : self.pos + 2]
            if two_char == "==":
                self.tokens.append(
                    Token(TokenType.DOUBLE_EQUAL, "==", start_line, start_col)
                )
                self.advance()
                self.advance()
                continue
            if two_char == "!=":
                self.tokens.append(
                    Token(TokenType.NOT_EQUAL, "!=", start_line, start_col)
                )
                self.advance()
                self.advance()
                continue
            if two_char == "~=":
                self.tokens.append(
                    Token(TokenType.NOT_EQUAL, "~=", start_line, start_col)
                )
                self.advance()
                self.advance()
                continue
            if two_char == "<=":
                self.tokens.append(
                    Token(TokenType.LESS_EQUAL, "<=", start_line, start_col)
                )
                self.advance()
                self.advance()
                continue
            if two_char == ">=":
                self.tokens.append(
                    Token(TokenType.GREATER_EQUAL, ">=", start_line, start_col)
                )
                self.advance()
                self.advance()
                continue

            # Single-character operators and delimiters
            single_char_tokens = {
                "+": TokenType.PLUS,
                "-": TokenType.MINUS,
                "*": TokenType.STAR,
                "/": TokenType.SLASH,
                "^": TokenType.CARET,
                "=": TokenType.EQUAL,
                "<": TokenType.LESS,
                ">": TokenType.GREATER,
                "&": TokenType.AMPERSAND,
                "|": TokenType.PIPE,
                "!": TokenType.BANG,
                "~": TokenType.TILDE,
                "(": TokenType.LPAREN,
                ")": TokenType.RPAREN,
                "[": TokenType.LBRACKET,
                "]": TokenType.RBRACKET,
                "{": TokenType.LBRACE,
                "}": TokenType.RBRACE,
                ",": TokenType.COMMA,
                ":": TokenType.COLON,
                ";": TokenType.SEMICOLON,
                ".": TokenType.DOT,
            }

            if char in single_char_tokens:
                self.tokens.append(
                    Token(single_char_tokens[char], char, start_line, start_col)
                )
                self.advance()
                continue

            # Unknown character - skip it
            self.advance()

        self.tokens.append(Token(TokenType.EOF, None, self.line, self.column))
        return self.tokens


class StataParser:
    """Parser for Stata commands."""

    def __init__(self):
        self.tokens: list[Token] = []
        self.pos = 0

    def peek(self, offset: int = 0) -> Token:
        """Look at token at current position + offset."""
        pos = self.pos + offset
        if pos >= len(self.tokens):
            return self.tokens[-1]  # EOF
        return self.tokens[pos]

    def advance(self) -> Token:
        """Move to next token and return current."""
        token = self.peek()
        self.pos += 1
        return token

    def match(self, *types: TokenType) -> bool:
        """Check if current token matches any of the given types."""
        return self.peek().type in types

    def expect(self, token_type: TokenType) -> Token:
        """Expect current token to be of given type."""
        if not self.match(token_type):
            raise SyntaxError(
                f"Expected {token_type}, got {self.peek().type} at line {self.peek().line}"
            )
        return self.advance()

    def parse_text(self, text: str) -> list[ParsedCommand]:
        """Parse Stata code text into commands."""
        lexer = StataLexer(text)
        self.tokens = lexer.tokenize()
        self.pos = 0
        return self.parse_commands()

    def parse_file(self, filepath: str) -> list[ParsedCommand]:
        """Parse a Stata file."""
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            return self.parse_text(f.read())

    def parse_commands(self) -> list[ParsedCommand]:
        """Parse multiple commands."""
        commands = []

        while not self.match(TokenType.EOF):
            # Skip empty lines
            while self.match(TokenType.NEWLINE):
                self.advance()

            if self.match(TokenType.EOF):
                break

            cmd = self.parse_command()
            if cmd:
                commands.append(cmd)

        return commands

    def parse_command(self) -> Optional[ParsedCommand]:
        """Parse a single Stata command."""
        if self.match(TokenType.EOF, TokenType.NEWLINE):
            return None

        cmd = ParsedCommand()
        raw_tokens = []

        # Collect raw line for debugging (preserve macro syntax and quotes)
        start_pos = self.pos
        while not self.match(TokenType.NEWLINE, TokenType.EOF):
            token = self.peek()
            if token.type == TokenType.MACRO_LOCAL:
                raw_tokens.append(f"`{token.value}'")
            elif token.type == TokenType.MACRO_GLOBAL:
                raw_tokens.append(f"${token.value}")
            elif token.type == TokenType.MACRO_SCALAR:
                raw_tokens.append(f"`={token.value}'")
            elif token.type == TokenType.STRING:
                # Preserve quotes around strings
                raw_tokens.append(f'"{token.value}"')
            elif token.value is not None:
                raw_tokens.append(str(token.value))
            self.advance()
        cmd.raw_line = " ".join(raw_tokens)

        # Reset position to parse properly
        self.pos = start_pos

        # Check for prefixes (by:, bysort:, quietly:, capture:, etc.)
        cmd = self._parse_prefix(cmd)

        # Parse main command name
        if self.match(TokenType.NAME, TokenType.KEYWORD):
            cmd.command = self.advance().value
        elif self.match(TokenType.RBRACE):
            # Closing brace is a command (ends block)
            cmd.command = "}"
            self.advance()
            # Skip to end of line
            while not self.match(TokenType.NEWLINE, TokenType.EOF):
                self.advance()
            if self.match(TokenType.NEWLINE):
                self.advance()
            return cmd
        else:
            # Skip to end of line
            while not self.match(TokenType.NEWLINE, TokenType.EOF):
                self.advance()
            return None

        # Parse arguments until we hit if/in/using/comma/newline
        cmd.arguments = self._parse_arguments()

        # Parse if condition
        if self.match(TokenType.KEYWORD) and self.peek().value == "if":
            self.advance()
            cmd.if_condition = self._parse_expression_until(
                {"in", "using"}, stop_at_comma=True
            )

        # Parse in range
        if self.match(TokenType.KEYWORD) and self.peek().value == "in":
            self.advance()
            cmd.in_range = self._parse_in_range()

        # Parse using clause
        if self.match(TokenType.KEYWORD) and self.peek().value == "using":
            self.advance()
            cmd.using = self._parse_using()

        # Parse options after comma
        if self.match(TokenType.COMMA):
            self.advance()
            cmd.options = self._parse_options()

        # Skip to end of line
        while not self.match(TokenType.NEWLINE, TokenType.EOF):
            self.advance()

        if self.match(TokenType.NEWLINE):
            self.advance()

        return cmd

    def _parse_prefix(self, cmd: ParsedCommand) -> ParsedCommand:
        """Parse command prefixes like by:, bysort:, quietly:, etc."""
        while True:
            if not self.match(TokenType.KEYWORD, TokenType.NAME):
                break

            token = self.peek()
            value = token.value.lower() if isinstance(token.value, str) else token.value

            # Check for by/bysort prefix
            if value in ("by", "bys", "bysort"):
                self.advance()
                cmd.prefix = "bysort" if value in ("bys", "bysort") else "by"

                # Parse by variables
                while self.match(TokenType.NAME):
                    cmd.prefix_vars.append(self.advance().value)

                # Parse sort variables in parentheses
                if self.match(TokenType.LPAREN):
                    self.advance()
                    while not self.match(TokenType.RPAREN, TokenType.EOF):
                        if self.match(TokenType.NAME):
                            cmd.prefix_sort_vars.append(self.advance().value)
                        else:
                            self.advance()
                    if self.match(TokenType.RPAREN):
                        self.advance()

                # Expect colon
                if self.match(TokenType.COLON):
                    self.advance()
                continue

            # Check for quietly/capture prefixes
            if value in ("quietly", "qui", "q"):
                self.advance()
                if self.match(TokenType.COLON):
                    self.advance()
                cmd.prefix = "quietly" if cmd.prefix is None else cmd.prefix
                continue

            if value in ("capture", "cap", "capt"):
                self.advance()
                if self.match(TokenType.COLON):
                    self.advance()
                cmd.prefix = "capture" if cmd.prefix is None else cmd.prefix
                continue

            if value == "noisily":
                self.advance()
                if self.match(TokenType.COLON):
                    self.advance()
                continue

            break

        return cmd

    def _parse_arguments(self) -> list:
        """Parse command arguments until if/in/using/comma/newline."""
        args = []
        stop_keywords = {"if", "in", "using"}

        while not self.match(TokenType.COMMA, TokenType.NEWLINE, TokenType.EOF):
            if self.match(TokenType.KEYWORD) and self.peek().value in stop_keywords:
                break

            token = self.advance()
            if token.type == TokenType.NAME:
                args.append(token.value)
            elif token.type == TokenType.STRING:
                args.append(f'"{token.value}"')
            elif token.type == TokenType.NUMBER:
                args.append(token.value)
            elif token.type == TokenType.MACRO_LOCAL:
                args.append(f"`{token.value}'")
            elif token.type == TokenType.MACRO_GLOBAL:
                args.append(f"${token.value}")
            elif token.type == TokenType.EQUAL:
                args.append("=")
            elif token.type in {
                TokenType.PLUS,
                TokenType.MINUS,
                TokenType.STAR,
                TokenType.SLASH,
                TokenType.CARET,
                TokenType.DOT,
                TokenType.COLON,
                TokenType.LESS,
                TokenType.GREATER,
                TokenType.LESS_EQUAL,
                TokenType.GREATER_EQUAL,
                TokenType.NOT_EQUAL,
                TokenType.BANG,
                TokenType.AMPERSAND,
                TokenType.PIPE,
                TokenType.TILDE,
            }:
                args.append(token.value)
            elif token.type == TokenType.LPAREN:
                # Parse parenthesized expression
                args.append("(")
                depth = 1
                while depth > 0 and not self.match(TokenType.EOF):
                    t = self.advance()
                    if t.type == TokenType.LPAREN:
                        depth += 1
                        args.append("(")
                    elif t.type == TokenType.RPAREN:
                        depth -= 1
                        args.append(")")
                    elif t.type == TokenType.NAME:
                        args.append(t.value)
                    elif t.type == TokenType.NUMBER:
                        args.append(str(t.value))
                    elif t.type == TokenType.STRING:
                        args.append(f'"{t.value}"')
                    else:
                        args.append(str(t.value) if t.value else "")
            elif token.type == TokenType.LBRACKET:
                # Weight specification [aweight=var]
                args.append("[")
                while not self.match(TokenType.RBRACKET, TokenType.EOF):
                    t = self.advance()
                    args.append(str(t.value) if t.value else "")
                if self.match(TokenType.RBRACKET):
                    args.append("]")
                    self.advance()

        return args

    def _parse_expression_until(
        self, stop_keywords: set, stop_at_comma: bool = False
    ) -> str:
        """Parse an expression until hitting stop keywords."""
        parts = []

        while not self.match(TokenType.NEWLINE, TokenType.EOF):
            if stop_at_comma and self.match(TokenType.COMMA):
                break
            if self.match(TokenType.KEYWORD) and self.peek().value in stop_keywords:
                break

            token = self.advance()
            if token.type == TokenType.NAME:
                parts.append(token.value)
            elif token.type == TokenType.STRING:
                parts.append(f'"{token.value}"')
            elif token.type == TokenType.NUMBER:
                parts.append(str(token.value))
            elif token.type == TokenType.MACRO_LOCAL:
                parts.append(f"`{token.value}'")
            elif token.type == TokenType.MACRO_GLOBAL:
                parts.append(f"${token.value}")
            elif token.value is not None:
                parts.append(str(token.value))

        return " ".join(parts)

    def _parse_in_range(self) -> tuple:
        """Parse in range specification (e.g., in 1/100)."""
        start = None
        end = None

        if self.match(TokenType.NUMBER):
            start = int(self.advance().value)

        if self.match(TokenType.SLASH):
            self.advance()
            if self.match(TokenType.NUMBER):
                end = int(self.advance().value)
            elif self.match(TokenType.NAME) and self.peek().value.lower() in ("l", "L"):
                end = -1  # Last observation
                self.advance()

        return (start, end)

    def _parse_using(self) -> str:
        """Parse using clause."""
        parts = []
        while not self.match(TokenType.COMMA, TokenType.NEWLINE, TokenType.EOF):
            if self.match(TokenType.KEYWORD) and self.peek().value in {"if", "in"}:
                break
            token = self.advance()
            if token.type == TokenType.STRING:
                parts.append(token.value)
            elif token.type == TokenType.NAME:
                parts.append(token.value)
            elif token.type == TokenType.MACRO_LOCAL:
                # Preserve macro reference format for later expansion
                parts.append(f"`{token.value}'")
            elif token.type == TokenType.MACRO_GLOBAL:
                parts.append(f"${token.value}")
            elif token.value is not None:
                parts.append(str(token.value))
        return "".join(parts).strip()

    def _parse_options(self) -> dict:
        """Parse options after comma."""
        options = {}

        while not self.match(TokenType.NEWLINE, TokenType.EOF):
            if self.match(TokenType.NAME, TokenType.KEYWORD):
                opt_name = self.advance().value

                # Check for option with argument
                if self.match(TokenType.LPAREN):
                    self.advance()
                    opt_value = self._parse_option_value()
                    options[opt_name] = opt_value
                else:
                    options[opt_name] = True
            else:
                self.advance()

        return options

    def _parse_option_value(self) -> str:
        """Parse option value inside parentheses."""
        parts = []
        depth = 1

        while depth > 0 and not self.match(TokenType.EOF):
            if self.match(TokenType.LPAREN):
                depth += 1
                parts.append("(")
                self.advance()
            elif self.match(TokenType.RPAREN):
                depth -= 1
                if depth > 0:
                    parts.append(")")
                self.advance()
            else:
                token = self.advance()
                if token.type == TokenType.STRING:
                    parts.append(f'"{token.value}"')
                elif token.value is not None:
                    parts.append(str(token.value))

        return " ".join(parts)


def preprocess_stata_code(code: str) -> str:
    """
    Preprocess Stata code to handle line continuations and clean up.

    Args:
        code: Raw Stata code

    Returns:
        Preprocessed code
    """
    lines = code.split("\n")
    result = []
    current_line = []

    for line in lines:
        stripped = line.rstrip()

        # Handle line continuation ///
        if stripped.endswith("///"):
            current_line.append(stripped[:-3].rstrip())
        else:
            current_line.append(stripped)
            result.append(" ".join(current_line))
            current_line = []

    # Handle any remaining continuation
    if current_line:
        result.append(" ".join(current_line))

    return "\n".join(result)
