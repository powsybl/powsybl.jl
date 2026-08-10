# Copyright (c) 2026, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

module Log
  using ..LibPowsybl
  using Logging

  # Levels understood by the Java side. PowSyBl maps these integers onto logback levels
  # (see PyLoggingUtil.pythonLevelToLogbackLevel): anything outside this set turns logging
  # off, which is why OFF is 0 and TRACE is 1.
  const OFF = 0
  const TRACE = 1
  const DEBUG = 10
  const INFO = 20
  const WARN = 30
  const ERROR = 40

  # Julia has no standard Trace level. This threshold is what a logger has to go below to
  # ask PowSyBl for TRACE detail; the messages themselves are still emitted at Debug,
  # because Julia drops anything below Debug before it reaches the logger.
  const TraceLevel = Logging.LogLevel(Logging.Debug.level - 1000)

  const _logger = Ref{Union{Nothing, AbstractLogger}}(nothing)

  """
      set_logger(logger::Union{AbstractLogger, Nothing})

  Send the PowSyBl (Java) log messages to `logger`. Passing `nothing` (the default) sends
  them to whichever logger is active when the operation runs, so `with_logger` and the
  global logger work as usual.

  This mirrors pypowsybl's `set_logger`: PowSyBl's verbosity follows the logger, there is
  no separate level to set. Lower the logger's minimum level to get more detail — at
  `Logging.Debug` and below PowSyBl also emits the Java stack traces.

  ```julia
  julia> using Logging
  julia> with_logger(ConsoleLogger(stderr, Logging.Debug)) do
           Powsybl.LoadFlow.run_ac(network, parameters)
         end
  ```
  """
  function set_logger(logger::Union{AbstractLogger, Nothing})
    _logger[] = logger
    sync_level()
    return nothing
  end

  """
      get_logger() -> AbstractLogger

  The logger the PowSyBl (Java) messages are sent to: the one set with [`set_logger`](@ref),
  or the currently active logger when none was set.
  """
  get_logger() = _logger[] === nothing ? current_logger() : _logger[]

  # Java level matching a logger's minimum enabled level.
  function java_level(logger::AbstractLogger)
    level = try
      Logging.min_enabled_level(logger)
    catch
      Logging.Info
    end
    level <= TraceLevel && return TRACE
    level <= Logging.Debug && return DEBUG
    level <= Logging.Info && return INFO
    level <= Logging.Warn && return WARN
    level <= Logging.Error && return ERROR
    return OFF
  end

  # Julia level for a message emitted by Java at the given level. PowSyBl TRACE and DEBUG
  # both surface as Debug: Julia filters levels below Debug out before they reach the
  # logger, so a dedicated trace level would simply be dropped. The original level is kept
  # on the message as java_level.
  function julia_level(level::Integer)
    level >= ERROR && return Logging.Error
    level >= WARN && return Logging.Warn
    level >= INFO && return Logging.Info
    return Logging.Debug
  end

  """
      sync_level()

  Tell the Java side the verbosity implied by the current logger. Called automatically
  before each PowSyBl operation, mirroring how pypowsybl re-applies the level read from
  its Python logger before every Java call.
  """
  sync_level() = (LibPowsybl.set_log_level_value(Int32(java_level(get_logger()))); nothing)

  """
      flush()

  Emit the PowSyBl (Java) log messages collected so far through the logger, each carrying
  the originating Java logger name and timestamp. Called automatically after each PowSyBl
  operation; only needed explicitly around calls that are not wrapped.
  """
  function flush()
    records = LibPowsybl.drain_java_log_records()
    isempty(records) && return nothing
    logger = get_logger()
    with_logger(logger) do
      for record in records
        fields = split(String(record), '\x1f'; limit = 4)
        length(fields) == 4 || continue
        level = tryparse(Int, fields[1])
        level === nothing && continue
        timestamp = something(tryparse(Int64, fields[2]), Int64(0))
        @logmsg(julia_level(level), fields[4], _group = :powsybl,
                java_logger_name = fields[3], java_timestamp = timestamp, java_level = level)
      end
    end
    return nothing
  end

  """
      with_java_logs(f)

  Run `f`, applying the current logger's verbosity to PowSyBl beforehand and emitting the
  messages it produced afterwards. Draining inside the caller's dynamic scope is what keeps
  `with_logger` working; the Java callback itself cannot log directly because it may run on
  a Java worker thread.
  """
  function with_java_logs(f)
    sync_level()
    try
      return f()
    finally
      flush()
    end
  end
end
