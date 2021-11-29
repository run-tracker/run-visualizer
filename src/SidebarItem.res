open Belt
open Routes
@react.component
let make = (~id: int, ~checkedIds: Set.Int.t, ~metadata) => {
  let url = ReasonReactRouter.useUrl()

  open Util
  let newIds = Set.Int.empty->Set.Int.add(id)
  let href = switch url->urlToRoute {
  | Valid(valid) => Valid({...valid, checkedIds: newIds})
  | _ => Js.Exn.raiseError(`The hash ${url.hash} should not route to here.`)
  }->routeToHref
  <li key={id->Int.toString} className="relative bg-white py-5 px-4 hover:bg-gray-50">
    <div className="flex space-x-3">
      <div className="p-4 space-y-10 flex items-center justify-center">
        <input
          id="candidates"
          name="candidates"
          type_="checkbox"
          checked={checkedIds->Set.Int.has(id)}
          onChange={_ => {
            let newIds =
              checkedIds->Set.Int.has(id)
                ? checkedIds->Set.Int.remove(id)
                : checkedIds->Set.Int.add(id)
            let href = switch url.hash->hashToRoute {
            | Valid(valid) => Valid({...valid, checkedIds: newIds})
            | _ => Js.Exn.raiseError(`The hash ${url.hash} should not route to here.`)
            }->routeToHref

            ReasonReactRouter.replace(href)
          }}
          className="focus:ring-indigo-500 h-4 w-4 filterKeywords-indigo-600 border-gray-300 rounded"
        />
      </div>
      <h3
        className="flex-shrink-0 flex items-center justify-center font-medium text-gray-900 truncate">
        <a href>
          {`${id->Int.toString}. ${metadata->Option.mapWithDefault("No metadata", metadata => {
              metadata
              ->jsonToMap
              ->Option.mapWithDefault("Ill-formatted metadata", map =>
                map
                ->Map.String.get("name")
                ->Option.mapWithDefault("No name field in metadata", name =>
                  name->Js.Json.decodeString->Option.getWithDefault(name->Js.Json.stringify)
                )
              )
            })}`->React.string}
        </a>
      </h3>
    </div>
    {if checkedIds->Set.Int.has(id) {
      metadata->Option.mapWithDefault(<> </>, metadata => {
        <div className="mt-1">
          <pre className="line-clamp-2 text-sm text-gray-600 p-4 font-extralight">
            {metadata->yaml({sortKeys: true})->React.string}
          </pre>
        </div>
      })
    } else {
      <> </>
    }}
  </li>
}