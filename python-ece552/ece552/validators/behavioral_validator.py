from pyslang import *
from .validator import Validator


simulation_statements = [
    # BlockStatement,
    BreakStatement,
    # CaseStatement,
    # ConcurrentAssertionStatement,
    # ConditionalStatement,
    ContinueStatement,
    DisableForkStatement,
    DisableStatement,
    DoWhileLoopStatement,
    # EmptyStatement,
    EventTriggerStatement,
    # ExpressionStatement,
    ForLoopStatement,
    # ForeachLoopStatement,
    # ForeverLoopStatement,
    ImmediateAssertionStatement,
    # InvalidStatement,
    # PatternCaseStatement,
    # ProceduralAssignStatement,
    ProceduralCheckerStatement,
    ProceduralDeassignStatement,
    RandCaseStatement,
    RandSequenceStatement,
    RepeatLoopStatement,
    ReturnStatement,
    # StatementList,
    # TimedStatement,
    # VariableDeclStatement,
    WaitForkStatement,
    WaitOrderStatement,
    WaitStatement,
    WhileLoopStatement,
]

simulation_expressions = [
    # ArbitrarySymbolExpression,
    AssertionInstanceExpression,
    # AssignmentExpression,
    AssignmentPatternExpressionBase, # TODO: what is this
    # BinaryExpression,
    # CallExpression,
    ClockingEventExpression,
    # ConcatenationExpression,
    # ConditionalExpression,
    # ConversionExpression,
    CopyClassExpression,
    # DataTypeExpression,
    DistExpression,
    # ElementSelectExpression,
    # EmptyArgumentExpression,
    InsideExpression,
    # IntegerLiteral,
    InvalidExpression,
    # LValueReferenceExpression,
    # MemberAccessExpression,
    MinTypMaxExpression,
    # NewArrayExpression,
    # NewClassExpression,
    NewCovergroupExpression,
    NullLiteral,
    # RangeSelectExpression,
    RealLiteral,
    # ReplicationExpression,
    # StreamingConcatenationExpression,
    StringLiteral,
    # TaggedUnionExpression,
    TimeLiteral,
    TypeReferenceExpression,
    # UnaryExpression,
    # UnbasedUnsizedIntegerLiteral,
    UnboundedLiteral,
    # ValueExpressionBase,
    ValueRangeExpression
]

constonly_expressions = [
    ArbitrarySymbolExpression,
    AssertionInstanceExpression,
    AssignmentExpression,
    AssignmentPatternExpressionBase,
    BinaryExpression,
    CallExpression,
    ClockingEventExpression,
    ConcatenationExpression,
    ConditionalExpression,
    ConversionExpression,
    CopyClassExpression,
    DataTypeExpression,
    DistExpression,
    ElementSelectExpression,
    EmptyArgumentExpression,
    InsideExpression,
    IntegerLiteral,
    InvalidExpression,
    LValueReferenceExpression,
    MemberAccessExpression,
    MinTypMaxExpression,
    NewArrayExpression,
    NewClassExpression,
    NewCovergroupExpression,
    NullLiteral,
    RangeSelectExpression,
    RealLiteral,
    ReplicationExpression,
    StreamingConcatenationExpression,
    StringLiteral,
    TaggedUnionExpression,
    TimeLiteral,
    TypeReferenceExpression,
    UnaryExpression,
    UnbasedUnsizedIntegerLiteral,
    UnboundedLiteral,
    ValueExpressionBase,
    ValueRangeExpression
]

timing_controls = [
    BlockEventListControl,
    CycleDelayControl,
    Delay3Control,
    DelayControl,
    # EventListControl,
    # ImplicitEventControl,
    InvalidTimingControl,
    OneStepDelayControl,
    RepeatedEventControl,
    # SignalEventControl
]


class BehavioralValidator(Validator):
    def __init__(self, compilation):
        super().__init__(compilation)
        self.timing = None

    def _validate_timing(self, timing: TimingControl):
        srcfile = self.source_file(timing.sourceRange.start)
        if any(isinstance(timing, T) for T in timing_controls):
            self.report(
                srcfile=srcfile,
                title="illegal or simulation only timing control",
                messages=[(Validator.span(timing.sourceRange), "timing control (event or delay) intended for simulation only or is disallowed")],
            )

        # Recursively check event lists.
        if isinstance(timing, EventListControl):
            for event in timing.events:
                self._validate_timing(event)

        # Only some types of events are allowed.
        if isinstance(timing, SignalEventControl):
            ok = True
            ok = ok and (timing.iffCondition is None)
            ok = ok and (timing.edge == EdgeKind.None_ or timing.edge == EdgeKind.PosEdge)
            if not ok:
                self.report(
                    srcfile=srcfile,
                    title="illegal or simulation only timing control",
                    messages=[(Validator.span(timing.sourceRange), "disallowed signal event")],
                )

    def __call__(self, obj: Token | SyntaxNode):
        # Check for disallowed statements, expressions, and simulation/verification constructs.
        if any(isinstance(obj, S) for S in simulation_statements):
            srcfile = self.source_file(obj.sourceRange.start)
            self.report(
                srcfile=srcfile,
                title="use of simulation only construct",
                messages=[(Validator.span(obj.sourceRange), "construct intended for simulation only and does not synthesize well")],
            )

        if any(isinstance(obj, S) for S in simulation_expressions):
            srcfile = self.source_file(obj.sourceRange.start)
            self.report(
                srcfile=srcfile,
                title="use of simulation only construct",
                messages=[(Validator.span(obj.sourceRange), "construct intended for simulation only and does not synthesize well")],
            )

        # Verify behavioral timing control. This course requires a single
        # clock signal in the sensitivity list (synchronous reset via
        # `if (i_rst) ... else ...` inside the clocked block, not a second
        # signal like `always @(posedge clk or posedge rst)`) -- that's
        # always been the rule, this validator just used to enforce it by
        # crashing. `EventListControl` (multiple signals) used to fall into
        # an `assert isinstance(obj.timing, ImplicitEventControl)` that
        # doesn't match it, raising an unhandled AssertionError -- a Python
        # traceback shown to the student as their compile error, not an
        # actual rule violation message. Same real outcome (rejected),
        # cleaner reporting.
        #
        # Separately, a SignalEventControl (single signal) whose expr is a
        # MemberAccessExpression rather than a bare NamedValueExpression
        # (e.g. `always @(posedge a.b)`) hit the same assert even though
        # it's still exactly one signal -- that shape is fine and is
        # handled generically below via `.syntax` instead of assuming a
        # specific expression type.
        if isinstance(obj, TimedStatement):
            self._validate_timing(obj.timing)

            if isinstance(obj.timing, ImplicitEventControl):
                self.timing = None
            elif isinstance(obj.timing, SignalEventControl):
                self.timing = str(obj.timing.expr.syntax).strip()
            elif isinstance(obj.timing, EventListControl):
                self.report(
                    srcfile=self.source_file(obj.timing.sourceRange.start),
                    title="multiple signals in sensitivity list",
                    messages=[(Validator.span(obj.timing.sourceRange),
                               "only a single clock signal is allowed here -- "
                               "use `if (i_rst) ... else ...` inside this "
                               "clocked block for synchronous reset instead "
                               "of a second signal")],
                )
                self.timing = str(obj.timing.syntax).strip()
            else:
                self.timing = str(obj.timing.syntax).strip()

        # Verify conditional statements. rf.v is exempt: the course's own
        # spec (project2.md, "Problem 2: Register File") explicitly says
        # "You may also use behavioral if/else Verilog for this problem
        # only" for the register-file bypass mux, which is combinational
        # (o_rs1_rdata/o_rs2_rdata aren't registered outputs). rf.v is a
        # fixed, required filename reused unmodified across every later
        # project (3-7 all carry the same rf.v forward, just with
        # BYPASS_EN=0), so the exemption follows the file, not the project
        # number -- the same submitted rf.v shouldn't pass validate in one
        # project and fail in the next. Every other file and every other
        # rule is unaffected.
        if isinstance(obj, ConditionalStatement):
            srcfile = self.source_file(obj.sourceRange.start)
            if self.timing is None and (srcfile.path is None or srcfile.path.name != "rf.v"):
                self.report(
                    srcfile=srcfile,
                    title="if/else statement not allowed in combinational logic",
                    messages=[(Validator.span(obj.sourceRange), "conditional statements (if/else) are only allowed for inferring registers in clocked blocks")],
                )

        # Verify blocks are sequential.
        if isinstance(obj, BlockStatement):
            ok = True
            ok = ok and obj.blockKind == StatementBlockKind.Sequential
            if not ok:
                self.report(
                    srcfile=self.source_file(obj.sourceRange.start),
                    title="illegal block kind",
                    messages=[(Validator.span(obj.sourceRange), "only sequential blocks are allowed, parallel (e.g. join) block detected")],
                )

        # Verify calls are only made to constexpr values.
        if isinstance(obj, CallExpression):
            if obj.constant is None:
                self.report(
                    srcfile=self.source_file(obj.sourceRange.start),
                    title="illegal call expression",
                    messages=[(Validator.span(obj.sourceRange), "functions calls are only allowed for constant expressions (like $clog2). $display, etc are unsynthesizable.")],
                )

        # Check that if/else statements are complete. Switch defaults are detected by
        # slang's builtin warnings.
        # if isinstance(obj, ConditionalStatement):
        #     if obj.ifFalse is None:
        #         self.report(
        #             srcfile=
        #         )
