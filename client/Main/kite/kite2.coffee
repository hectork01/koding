class KDKite extends Kite

  @createMethod = (ctx, { method, rpcMethod }) ->
    ctx[method] = (rest...) -> @tell2 rpcMethod, rest...

  @createApiMapping = (api) ->
    for own method, rpcMethod of api
      @::[method] = @createMethod @prototype, { method, rpcMethod }

  @constructors = {}

  createProperError = (err) ->
    e = new Error err.message
    e.type = err.type
    e

  tell2: (method, params = {}) ->
    { correlationName, kiteName, timeout: classTimeout } = @getOptions()

    # #tell2 is wrapping #tell with a promise-based api
    new Promise (resolve, reject) =>

      options = {
        method
        kiteName
        correlationName
        withArgs: params
      }

      callback = (err, restResponse...) ->
        return reject createProperError err   if err?
        return resolve restResponse...

      @tell options, callback

    .timeout classTimeout ? 5000
