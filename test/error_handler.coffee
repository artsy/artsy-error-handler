rewire = require 'rewire'
sinon = require 'sinon'
express = require 'express'
jade = require 'jade'
fs = require 'fs'
{ resolve } = require 'path'
errorHandler = rewire '../routes'

beforeEach ->
  errorHandler(template: __dirname + '/template.jade', showDetail: true)

describe '#internalError', ->

  it 'renders a 500 page', ->
    errorHandler.internalError new Error("Some blah error"), {},
      { statusCode: 500, send: spy = sinon.spy(), status: -> }
    spy.args[0][0].should.containEql "Some blah error"

  it 'sends a 500 by default', ->
    errorHandler.internalError new Error("Some blah error"), {},
      { statusCode: 500, send: spy = sinon.spy(), status: status = sinon.stub() }
    status.args[0][0].should.equal 500

  it 'will look at the errors status', ->
    err = new Error("Some blah error")
    err.status = 404
    errorHandler.internalError err, {},
      { statusCode: 500, send: spy = sinon.spy(), status: status = sinon.stub() }
    status.args[0][0].should.equal 404

describe '#pageNotFound', ->

  it 'renders a 404 page', ->
    # Fake a Express request object with Accept header set
    req = express.request
    req.headers = Accept: 'text/html'
    errorHandler.pageNotFound req, { send: spy = sinon.spy(), status: stub = sinon.stub() }
    stub.args[0][0].should.equal 404
    spy.args[0][0].should.containEql "The page you were looking for doesn't exist"

describe '#socialAuthError', ->

  it 'redirects to a login error', ->
    errorHandler.socialAuthError "User Already Exists", {}, @res = { redirect: sinon.stub() }
    @res.redirect.args[0][0].should.equal '/log_in?error=already-signed-up'

  it 'uses gravity style error messages if coming from facebook', ->
    errorHandler.socialAuthError "User Already Exists", { url: 'facebook' }, @res = { redirect: sinon.stub() }
    @res.redirect.args[0][0].should.equal '/log_in?account_created_email=facebook'

  it 'uses gravity style error messages if coming from tiwtter', ->
    errorHandler.socialAuthError "User Already Exists", { url: 'twitter' }, @res = { redirect: sinon.stub() }
    @res.redirect.args[0][0].should.equal '/log_in?account_created_email=twitter'

  it 'directs social linking errors to the user edit page', ->
    errorHandler.socialAuthError "Another Account Already Linked: Twitter", { url: 'twitter' }, @res = { redirect: sinon.stub() }
    @res.redirect.args[0][0].should.equal '/user/edit?error=twitter-already-linked'

describe '#template', ->

  it 'renders the error message if showDetail is true', ->
    jade.render(fs.readFileSync(resolve __dirname + '/template.jade').toString(), { detail: 'Catty Error', showDetail: true }).should.containEql 'Catty Error'

  it 'wont render error details if showDetail if false', ->
    jade.render(fs.readFileSync(resolve __dirname + '/template.jade').toString(), { detail: 'Catty Error', showDetail: false }).should.not.containEql 'Catty Error'

describe 'Backbone error', ->

  beforeEach ->
    @req = {}
    @res = { status: sinon.stub() }
    @next = sinon.stub()
    errorHandler.backboneErrorHelper @req, @res, @next

  it 'adds a backbone error handler helper', ->
    @res.backboneError {}, { error: {}, text: '{"error":"Foo Err"}' }
    @next.args[1][0].toString().should.containEql 'Foo Err'

  it 'handles generic stringy errors', ->
    @res.backboneError {}, { error: 'Foo Err' }
    @next.args[1][0].toString().should.containEql 'Foo Err'

  it 'turns 403 errors into 404s', ->
    errorHandler.__set__ 'NODE_ENV', 'production'
    @res.backboneError {}, { error: { status: 403 } }
    @next.args[1][0].toString().should.containEql 'Not Found'

  it 'attaches API status to the errors', ->
    errorHandler.__set__ 'NODE_ENV', 'production'
    @res.backboneError {}, { error: { status: 404 } }
    @next.args[1][0].status.should.equal 404

