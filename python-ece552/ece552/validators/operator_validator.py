from pyslang import (
    Token, SyntaxNode, UnaryExpression, BinaryExpression, UnaryOperator, BinaryOperator,
    ExpressionKind, ASTContext, EvalContext, LookupLocation,
)
from .validator import Validator


# This dict (plus binary_ops below) is what's actually enforced -- it
# should match the "Operator Restrictions" section of the wisc26 site
# repo's site/rules.md (a different repo, not cross-linkable here) point
# for point in both directions. They've drifted before in this exact spot
# (rules.md once documented && / || as banned when this dict had already
# stopped enforcing that) -- if you change one, check the other.
#
# Operators are blacklisted along with a reason
unary_ops = {
    # UnaryOperator.Plus,
    # UnaryOperator.Minus,
    # UnaryOperator.BitwiseNot,
    # UnaryOperator.BitwiseAnd,
    # UnaryOperator.BitwiseOr,
    # UnaryOperator.BitwiseXor,
    # UnaryOperator.BitwiseNand,
    # UnaryOperator.BitwiseNor,
    # UnaryOperator.BitwiseXnor,
    # UnaryOperator.LogicalNot,
    # UnaryOperator.Preincrement,
    # UnaryOperator.Predecrement,
    # UnaryOperator.Postincrement,
# UnaryOperator.Postdecrement,
}

binary_ops = {
    # BinaryOperator.Add,
    # BinaryOperator.Subtract,
    BinaryOperator.Multiply: "multiply operator '*' synthesizes poorly",
    BinaryOperator.Divide: "divide operator '/' synthesizes poorly",
    BinaryOperator.Mod: "modulo operator '%' synthesizes poorly",
    # BinaryOperator.BinaryAnd,
    # BinaryOperator.BinaryOr,
    # BinaryOperator.BinaryXor,
    # BinaryOperator.BinaryXnor,
    # BinaryOperator.Equality,
    # BinaryOperator.Inequality,
    BinaryOperator.CaseEquality: "case equality operator '===' is not synthesizable",
    BinaryOperator.CaseInequality: "case inequality operator '!==' is not synthesizable",
    # BinaryOperator.GreaterThanEqual,
    # BinaryOperator.GreaterThan,
    # BinaryOperator.LessThanEqual,
    # BinaryOperator.LessThan,
    # These could be allowed with further constexpr analysis, but blacklist for now.
    BinaryOperator.WildcardEquality: "wildcard equality operator '==?' may synthesize poorly",
    BinaryOperator.WildcardInequality: "wildcard inequality operator '!=?' may synthesize poorly",
    # BinaryOperator.LogicalAnd,
    # BinaryOperator.LogicalOr,
    # BinaryOperator.LogicalImplication,
    # BinaryOperator.LogicalEquivalence,
    # BinaryOperator.LogicalShiftLeft,
    # BinaryOperator.LogicalShiftRight,
    # BinaryOperator.ArithmeticShiftLeft,
    # BinaryOperator.ArithmeticShiftRight,
    BinaryOperator.Power: "power operator '**' synthesizes poorly",
}


class OperatorValidator(Validator):
    def __init__(self, compilation):
        super().__init__(compilation)
        # A scratch scope purely so shift amounts can be constant-folded via
        # .eval() below -- name resolution has already happened during the
        # compilation's own elaboration, this scope is never used to look
        # anything up itself.
        self._scope = compilation.createScriptScope()

    def _report_invalid(self, expr: UnaryExpression | BinaryExpression, reason: str):
        srcfile = self.source_file(expr.sourceRange.start)
        self.report(
            srcfile=srcfile,
            title="operator not synthesizable or disallowed",
            messages=[(Validator.span(expr.sourceRange), reason)],
            hint="if really needed, please implement operator manually",
        )

    def _shift_illegal(self, expr: BinaryExpression) -> bool:
        shift = expr.op in [
            BinaryOperator.LogicalShiftLeft,
            BinaryOperator.LogicalShiftRight,
            BinaryOperator.ArithmeticShiftLeft,
            BinaryOperator.ArithmeticShiftRight,
        ]

        if shift:
            amount = expr.right
            if amount.kind == ExpressionKind.IntegerLiteral:
                return False
            # amount.constant is only populated for expressions pyslang
            # happened to fold during elaboration (e.g. array-dimension
            # bounds) -- it's None for a shift amount even when that amount
            # genuinely is a compile-time constant (a parameter, a
            # localparam, `2 + 1`, or a genvar-derived expression inside a
            # generate block, e.g. a barrel shifter's `1 << i`). Actually
            # constant-fold it via .eval() instead of trusting .constant:
            # a real (non-constant) reference like a wire/reg fails to
            # evaluate and .eval() returns an empty/falsy ConstantValue.
            ctx = EvalContext(ASTContext(self._scope, LookupLocation.max))
            if amount.eval(ctx):
                return False
            return True
        return False

    def __call__(self, obj: Token | SyntaxNode):
        # Check operators against the blacklist.
        if isinstance(obj, UnaryExpression):
            if obj.op in unary_ops:
                self._report_invalid(obj, unary_ops[obj.op])
        if isinstance(obj, BinaryExpression):
            if obj.op in binary_ops:
                self._report_invalid(obj, binary_ops[obj.op])

        # Check that shifts only shift by constant amounts.
        if isinstance(obj, BinaryExpression):
            if self._shift_illegal(obj):
                self._report_invalid(obj, "shift amount is not a constant expression")
