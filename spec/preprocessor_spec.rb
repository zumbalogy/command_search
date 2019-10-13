load(__dir__ + '/./spec_helper.rb')

describe CommandSearch::Preprocessor do

  Field_default = []
  Cmd_default = { a: Boolean, s: String }

  def opt(x, fields = Field_default, command_fields = Cmd_default)
    ast = CommandSearch::Lexer.lex(x)
    CommandSearch::Parser.parse!(ast)
    CommandSearch::Optimizer.optimize(ast)
    CommandSearch::Normalizer.normalize!(ast, command_fields)
    ast
  end

  def n(x, fields = Field_default, command_fields = Cmd_default)
    opted = opt(x, fields, command_fields)
    preprocessed = CommandSearch::Preprocessor.sql_preprocess(opted, fields, command_fields)
  end

  it 'should unroll negation' do
    n('-(a|b)').should == [{negate: true, type: :str, value: /a/i}, {negate: true, type: :str, value: /b/i}]
    n('(-a -b)').should == [{negate: true, type: :str, value: /a/i}, {negate: true, type: :str, value: /b/i}]

    n('-a').should_not == n('a')
    n('-(-a)').should == n('a')
    n('-(-(-a))').should == n('-a')
    n('-(a|b)').should == n('(-a -b)')
    n('-(a b)').should == n('-a|-b')
    n('-(a|-b)').should == n('-a b')
    n('-(a -b)').should == n('-a|b')
    n('-(-a|b)').should == n('a -b')
    n('-(-a b)').should == n('a|-b')
    n('-(-(a|-b))').should == n('a|-b')
    n('-(-(-(-a b)))').should == n('a|-b')
    n('-(-(-(-a) b))').should == n('a b')
    n('-(-(-(-a)) b)').should == n('a|-b')
    n('-(a|b)|-(c|d)').should == n('(-a -b)|(-c -d)')
  end

  it 'should negate colon commands correctly' do
    n('-s:5').should == [{
      negate: true,
      nest_op: ':',
      nest_type: :colon,
      type: :nest,
      value: [{type: :str, value: 's'}, {type: :number, value: /5/i}]
    }]
    n('a:-5').should == opt('a:-5')
  end

  it 'should unroll negations with compares' do
    n('-a<1').should == n('a>=1')
    n('-a>1').should == n('a<=1')
    n('-a>=1').should == n('a<1')
    n('-a<=1').should == n('a>1')
  end
end
