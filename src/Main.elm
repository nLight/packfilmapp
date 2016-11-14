port module Main exposing (..)

import Dict exposing (Dict)
import Html exposing (Html, a, div, nav, text, img, h1)
import Html.Attributes exposing (href, src, class)
import Http
import Maybe
import Media exposing (Media)
import Task
import Token
import User exposing (User)
import Users


port saveToken : String -> Cmd msg


type alias Model =
    { apiHost : String
    , streams : Dict String Stream
    , messages : List String
    }


type Msg
    = ApiError Http.Error
    | GenericError String
    | GetFeedSuccess String (List (List Media))
    | GetMediaSuccess String (List Media)
    | GetUserSuccess String User.User
    | SilentError String
    | SuccessStreams
    | SuccessToken String


type alias Flags =
    { apiHost : String
    , streams : Maybe (List ( String, Stream ))
    }


type alias Stream =
    { user : Maybe User
    , recent : List (Media.Media)
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        streams =
            Dict.fromList (Maybe.withDefault [] flags.streams)

        apiHost =
            flags.apiHost
    in
        ( { apiHost = apiHost
          , streams = streams
          , messages = []
          }
        , Cmd.batch
            (loadStreams apiHost streams
                ++ [ (Task.fromMaybe "Token not found" Token.getToken |> Task.perform SilentError SuccessToken)
                   ]
            )
        )


update msg model =
    case msg of
        SuccessToken token ->
            ( { model | streams = (Dict.insert token emptyStream model.streams) }
            , Cmd.batch
                [ (saveToken token)
                , (loadFeed model.apiHost token) |> Task.perform ApiError (GetFeedSuccess token)
                , (User.getUserSelf model.apiHost token) |> Task.perform ApiError (GetUserSuccess token)
                -- , (Media.getSelf model.apiHost token) |> Task.perform ApiError (GetMediaSuccess token)
                ]
            )

        GetFeedSuccess token list ->
            ( model, Cmd.none )

        GetUserSuccess token user ->
            updateStream model token (updateStreamUser user)

        GetMediaSuccess token recent ->
            updateStream model token (updateStreamRecent recent)

        GenericError error ->
            ( { model | messages = [ error ] }, Cmd.none )

        _ ->
            ( model, Cmd.none )


loadFeed apiHost token =
    (Users.getFriends apiHost token) `Task.andThen` (\friends -> (Task.sequence (List.map (\user -> Media.get apiHost token user.id) friends)))


loadStreams apiHost streams =
    List.map
        (\token ->
            Cmd.batch
                [ (Media.getSelf apiHost token) |> Task.perform ApiError (GetMediaSuccess token)
                , (User.getUserSelf apiHost token) |> Task.perform ApiError (GetUserSuccess token)
                ]
        )
        (Dict.keys streams)


updateStream model token update =
  let
      streams' =
          Dict.update token update model.streams
  in
      ( { model | streams = streams' }, Cmd.none )


updateStreamUser : User -> (Maybe Stream -> Maybe Stream)
updateStreamUser user stream =
    case stream of
        Just stream ->
            Just { stream | user = Just user }

        Nothing ->
            Just { emptyStream | user = Just user }


updateStreamRecent : List Media.Media -> (Maybe Stream -> Maybe Stream)
updateStreamRecent media stream =
    case stream of
        Just stream ->
            Just { stream | recent = media }

        Nothing ->
            Just { emptyStream | recent = media }


emptyStream =
    { user = Nothing
    , recent = []
    }


login_button =
    a
        [ class "btn btn-outline-primary"
        , href "https://api.instagram.com/oauth/authorize/?client_id=a59977aae66341598cb366c081e0b62d&redirect_uri=http://packfilmapp.com&response_type=token"
        ]
        [ text "Add Stream" ]


streams data =
    (List.map stream (Dict.values data))


stream data =
    div [ class "col-xs-4" ]
        [ div []
            [ div []
                [ User.cardView data.user
                , div [] (List.map Media.view data.recent)
                ]
            ]
        ]


messages data =
    List.map (\message -> div [ class "alert alert-danger" ] [ text message ]) data


view model =
    div []
        [ nav [ class "navbar navbar-full navbar-light bg-faded navbar-static-top" ]
            [ a [ class "navbar-brand" ] [ text "Packfilm" ]
            ]
        , div [ class "container-fluid" ]
            [ div [ class "row" ]
                [ div [ class "col-xs-12" ] (messages model.messages)
                ]
            , div [ class "row" ]
                ((streams model.streams) ++ [ div [] [ login_button ] ])
            ]
        ]
