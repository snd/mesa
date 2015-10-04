assert = require 'assert'
# prototype chain length: always 0
# property count of every object in chain = default methods + attributes
#
# supports extension of fluent interface: true
# number of objects in memory: just the ends of the chain

mesa =
  clone: ->
    clone = Object.create null
    for k, v of this
      clone[k] = v
    return clone
  fluent: (key, value) ->
    next = @clone()
    next[key] = value
    return next

  alpha: (arg) -> @fluent '_alpha', arg
  bravo: (arg) -> @fluent '_bravo', arg
  charlie: (arg) -> @fluent '_charlie', arg
  delta: (arg) -> @fluent '_delta', arg
  echo: (arg) -> @fluent '_echo', arg

benchmark = (n) ->
  console.log('# n = ' + n + '\n')
  console.time "n = #{n}"

  object = mesa

  console.time 'object.alpha(i)'
  [0..n].forEach ->
    object = object.alpha(n)
  console.timeEnd 'object.alpha(i)'
  console.log 'process.memoryUsage()', process.memoryUsage()

  console.time 'object.bravo(i)'
  [0..n].forEach (i) ->
    object = object.bravo(i)
  console.timeEnd 'object.bravo(i)'
  console.log 'process.memoryUsage()', process.memoryUsage()

  console.time 'object.charlie(i)'
  [0..n].forEach (i) ->
    object = object.charlie(i)
  console.timeEnd 'object.charlie(i)'
  console.log 'process.memoryUsage()', process.memoryUsage()

  console.time 'object.delta(i)'
  [0..n].forEach (i) ->
    object = object.delta(i)
  console.timeEnd 'object.delta(i)'
  console.log 'process.memoryUsage()', process.memoryUsage()

  console.time 'object.echo(i)'
  [0..n].forEach (i) ->
    object = object.echo(i)
  console.timeEnd 'object.echo(i)'
  console.log 'process.memoryUsage()', process.memoryUsage()

  console.time 'object._alpha'
  console.log object._alpha
  console.timeEnd 'object._alpha'

  console.time 'object._bravo'
  console.log object._bravo
  console.timeEnd 'object._bravo'

  console.time 'object._charlie'
  console.log object._charlie
  console.timeEnd 'object._charlie'

  console.time 'object._delta'
  console.log object._delta
  console.timeEnd 'object._delta'

  console.time 'object._echo'
  console.log object._echo
  console.timeEnd 'object._echo'

  console.timeEnd "n = #{n}"
  console.log '\n'

benchmark(10)
benchmark(100)
benchmark(1000)
benchmark(10000)
benchmark(100000)
benchmark(1000000)
