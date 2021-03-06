open Belt

@val external maxLogs: string = "NODE_MAX_LOGS"

module EveryQuery = %graphql(`
  query logs($condition: run_log_bool_exp!) {
    run_log(where: $condition) {
      id
      log
    }
  }
`)

module EveryNthQuery = %graphql(`
  query logs($condition: run_log_bool_exp!, $n: Int!) {
    every_nth_run_log(args: {n: $n}, where: $condition) {
      id
      log
    }
  }
`)

module ExceptEveryNthQuery = %graphql(`
  query logs($condition: run_log_bool_exp!, $n: Int!) {
    except_every_nth_run_log(args: {n: $n}, where: $condition) {
      id
      log
    }
  }
`)

let addParametersToLog = (log, metadata) => {
  open Util
  metadata
  ->jsonToMap
  ->Option.flatMap(o => o->Map.String.get("parameters")) // To Do: do not hard-code this somehow
  ->Option.flatMap(jsonToMap)
  ->Option.flatMap(parameters =>
    log->jsonToMap->Option.map(logMap => parameters->Map.String.merge(logMap, merge)->mapToJson)
  )
  ->Option.getWithDefault(log)
}

type queryResult = Util.queryResult<Map.Int.t<Js.Json.t>>

let useLogs = (
  ~logCount: int,
  ~checkedIds: Set.Int.t,
  ~granularity: Routes.granularity,
): queryResult => {
  let ids = checkedIds->Set.Int.toArray
  let toData = (x): queryResult => x->Map.Int.fromArray->Data
  maxLogs
  ->Int.fromString
  ->Option.mapWithDefault(
    (Error(`Invalid value for NODE_MAX_LOGS: ${maxLogs}`): queryResult),
    maxLogs =>
      if logCount < maxLogs {
        let condition = switch granularity {
        | Run =>
          let run_id = EveryQuery.makeInputObjectInt_comparison_exp(~_in=ids, ())
          let condition = EveryQuery.makeInputObjectrun_log_bool_exp(~run_id, ())
          condition
        | Sweep =>
          let sweep_id = EveryQuery.makeInputObjectInt_comparison_exp(~_in=ids, ())
          let run = EveryQuery.makeInputObjectrun_bool_exp(~sweep_id, ())
          let condition = EveryQuery.makeInputObjectrun_log_bool_exp(~run, ())
          condition
        }
        switch EveryQuery.use({condition: condition}) {
        | {loading: true} => Loading
        | {error: Some(error)} => Error(error.message)
        | {data: None, error: None, loading: false} => Stuck
        | {data: Some({run_log})} => run_log->Array.map(({id, log}) => (id, log))->toData
        }
      } else if logCount < 2 * maxLogs {
        let n: int = logCount / (logCount - maxLogs)
        let condition = switch granularity {
        | Run =>
          let run_id = ExceptEveryNthQuery.makeInputObjectInt_comparison_exp(~_in=ids, ())
          let condition = ExceptEveryNthQuery.makeInputObjectrun_log_bool_exp(~run_id, ())
          condition
        | Sweep =>
          let sweep_id = ExceptEveryNthQuery.makeInputObjectInt_comparison_exp(~_in=ids, ())
          let run = ExceptEveryNthQuery.makeInputObjectrun_bool_exp(~sweep_id, ())
          let condition = ExceptEveryNthQuery.makeInputObjectrun_log_bool_exp(~run, ())
          condition
        }
        switch ExceptEveryNthQuery.use({condition: condition, n: n}) {
        | {loading: true} => Loading
        | {error: Some(error)} => Error(error.message)
        | {data: None, error: None, loading: false} => Stuck
        | {data: Some({except_every_nth_run_log})} =>
          except_every_nth_run_log->Array.map(({id, log}) => (id, log))->toData
        }
      } else {
        let n: int = logCount / maxLogs
        let condition = switch granularity {
        | Run =>
          let run_id = EveryNthQuery.makeInputObjectInt_comparison_exp(~_in=ids, ())
          let condition = EveryNthQuery.makeInputObjectrun_log_bool_exp(~run_id, ())
          condition
        | Sweep =>
          let sweep_id = EveryNthQuery.makeInputObjectInt_comparison_exp(~_in=ids, ())
          let run = EveryNthQuery.makeInputObjectrun_bool_exp(~sweep_id, ())
          let condition = EveryNthQuery.makeInputObjectrun_log_bool_exp(~run, ())
          condition
        }
        switch EveryNthQuery.use({condition: condition, n: n}) {
        | {loading: true} => Loading
        | {error: Some(error)} => Error(error.message)
        | {data: None, error: None, loading: false} => Stuck
        | {data: Some({every_nth_run_log})} =>
          every_nth_run_log->Array.map(({id, log}) => (id, log))->toData
        }
      },
  )
}
