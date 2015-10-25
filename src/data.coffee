EventEmitter = require 'eventemitter3'
_ = require 'lodash'

# sum = (numbers...) ->
#   result = 0
#   for number in numbers[0]
#     result += number
#   return result

# fns =
#   sum: sum

class Data extends EventEmitter
  constructor: (json) ->
    @properties = {}
    if json.value
      @value(json.value)
    delete json.value
    _.assign @properties, json
  get: (name) ->
    return @properties[name] or undefined
  value: (value) ->
    if value or value is 0
      @val = value
      @emit 'change:value'
    return @val
  set: (name, value) ->
    @properties[name] = value
    if name is 'expression'
      @attachListeners(@stack)
    return
  evaluate: (stack) ->
    expression = @get('expression')
    if expression
      if expression.indexOf('return') is -1
        expression = 'return ' + expression
      myEval.call(stack, expression, (result) =>
        @value(result)
      )
  attachListeners: (originalStack) ->
    expression = @get('expression')

    # remove myself from the stack
    stack = originalStack.filter (item) =>
      return item.get('name') isnt @get('name')

    # if the data object has an expression (depends on others)
    if expression
      # go through the whole stack and check every name
      # if a name is inside the expression, its a dependency of the current data
      for foreign in stack
        if expression.indexOf(foreign.get('name')) > -1
          @evaluate(stack)
          # console.log foreign.get('name'), 'is a dependency to', @get('name')
          # this foreign-data is a dependency of data, listen to its changes
          # and if it does change, evaluate the local-data's expression
          foreign.on 'change:value', =>
            @evaluate(stack)

    return

module.exports = Data

createScope = (stack) ->
  scope = {}
  for data in stack
    val = data.value()
    scope[data.get('name')] = val
  return scope

myEval = _.debounce (exp, cb) ->
  # exp = '(function() { ' + exp + ' }.call(this))'
  # (->
  #   x = eval(exp)
  #   cb(x)
  # ).call(@)
  # if exp.match(/:/).length
  #   exp = exp.replace(/:/g, '$range$')
  #   left = exp.split('$range$')[0].split('(')[1]
  #   right = exp.split('$range$')[1].split(')')[0]
  #   startcolumn = left[0]
  #   endcolumn = right[0]

  #   startnum = left.substr(1, left.length-1)
  #   endnum = right.substr(1, right.length-1)

  #   range = left + '$range$' + right

  #   @[range] = []
  #   for key, value of @
  #     if @[key]
  #       if typeof(key) isnt 'function'
  #         if key.indexOf('range') is -1
  #           if key[0] is startcolumn or key[0] is endcolumn
  #             currentRow = parseInt key.substr(1, key.length-1)
  #             if currentRow >= startnum and currentRow <= endnum
  #               @[range].push @[key]
  #
  scope = createScope(@)

  x = (new Function 'with(this) { ' + exp + ' }').call(scope)
  cb(x)
, 0

