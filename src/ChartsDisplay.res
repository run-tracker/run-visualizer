open Belt

module Query = LogsQuery.EveryQuery

module Subscription = %graphql(`
subscription MaxRunLogId($condition: run_log_bool_exp!) {
  run_log_aggregate(where: $condition) {
    aggregate {
      max {
        id
      }
    }
  }
}
`)

@react.component
let make = (
  ~specs: Map.t<Js.Json.t, Util.chartState, Util.JsonComparator.identity>,
  ~logs,
  ~checkedIds,
  ~granularity: Routes.granularity,
  ~dispatch,
  ~client: ApolloClient__Core_ApolloClient.t,
) => {
  let initialLogs = logs
  let (logs, _) = React.useState(_ => initialLogs) // Freeze initial value for logs
  let (executeQuery, queryResult) = Query.useLazy()
  let (error, setError) = React.useState(() => None)
  let (timedOut, setTimedOut) = React.useState(() => true)
  let (_, setMinLogId) = React.useState(_ => logs->Map.Int.maxKey->Option.getWithDefault(0))

  React.useEffect3(() => {
    // Set up subscription to max run_log id
    let onError = error => setError(_ => error->Some)
    let onNext = (value: ApolloClient__Core_ApolloClient.FetchResult.t__ok<Subscription.t>) => {
      switch value {
      | {error: Some(error)} => error->onError
      | {data: {run_log_aggregate: {aggregate: Some({max: Some({id: Some(maxLogId)})})}}} =>
        // When run_log id increases, query for new logs
        if timedOut {
          // First condition: logs belong to checked runs
          let run = switch granularity {
          | Sweep =>
            let sweep_id = Query.makeInputObjectInt_comparison_exp(
              ~_in=checkedIds->Set.Int.toArray,
              (),
            )
            Query.makeInputObjectrun_bool_exp(~sweep_id, ())
          | Run =>
            let id = Query.makeInputObjectInt_comparison_exp(~_in=checkedIds->Set.Int.toArray, ())
            Query.makeInputObjectrun_bool_exp(~id, ())
          }
          let condition1 = Query.makeInputObjectrun_log_bool_exp(~run, ())

          setMinLogId(minLogId => {
            // Second condition: logs have a greater id than minLogId
            let id = Query.makeInputObjectInt_comparison_exp(~_gt=minLogId, ())
            let condition2 = Query.makeInputObjectrun_log_bool_exp(~id, ())

            let _and = [condition1, condition2]
            let condition = Query.makeInputObjectrun_log_bool_exp(~_and, ())

            // Uncomment to print condition as JSON:

            Js.log(
              {condition: condition}
              ->Query.serializeVariables
              ->Query.variablesToJson
              ->Js.Json.stringifyWithSpace(2),
            )

            executeQuery({condition: condition})
            maxLogId // return maxLogId value to setMinLogId callback, updating minLogId
          })

          // reset debounce timer
          setTimedOut(_ => false)
          Js.Global.setTimeout(() => setTimedOut(_ => true), 5000)->ignore
        }
      | _ => ()
      }
    }

    let id = Subscription.makeInputObjectInt_comparison_exp(~_in=checkedIds->Set.Int.toArray, ())
    let run = Subscription.makeInputObjectrun_bool_exp(~id, ())
    let condition = Subscription.makeInputObjectrun_log_bool_exp(~run, ())
    let subscription =
      client.subscribe(~subscription=module(Subscription), {condition: condition}).subscribe(
        ~onNext,
        ~onError,
        (),
      )->Some
    Some(_ => (subscription->Option.getExn).unsubscribe())
  }, (checkedIds, client, timedOut))
  <>
    {switch error {
    | None => <> </>
    | Some({message}) =>
      let message = `MaxRunLogId subscription error: ${message}`
      <ErrorPage message />
    }}
    {switch queryResult {
    | Executed({error: Some({message})}) =>
      let message = `LogsQuery.EveryQuery error: ${message}`
      <ErrorPage message />
    | _ => <> </>
    }}
    {specs
    ->Map.toArray
    ->List.fromArray
    ->List.sort(((_, {order: order1}), (_, {order: order2})) => order1 - order2)
    ->List.mapWithIndex((i, (spec, {rendering, ids: chartIds})) => {
      let key = i->Int.toString
      if rendering {
        let newLogs = switch queryResult {
        | Executed({data: Some({run_log})}) => run_log
        | _ => []
        }
        <div className="pb-10" key>
          <Chart logs newLogs spec /> <ChartButtons spec chartIds dispatch />
        </div>
      } else {
        let initialSpec = spec
        <SpecEditor key initialSpec dispatch />
      }
    })
    ->List.toArray
    ->React.array}
  </>
}
