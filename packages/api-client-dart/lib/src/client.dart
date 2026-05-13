// `ReverseMatchApiClient` — the public facade exposed to consumers.
//
// Consumers (e.g. the `reverse_match` Flutter app) inject their own Dio
// instance — which carries the auth-refresh interceptor, the dummy
// interceptor in dev, and any logging/Sentry interceptors they want. This
// way the generated API surface stays a thin protocol layer and all
// cross-cutting concerns live in the caller's Dio.

import 'package:dio/dio.dart';

import 'apis/account_api.dart';
import 'apis/auth_api.dart';
import 'apis/boost_api.dart';
import 'apis/config_api.dart';
import 'apis/ideal_match_api.dart';
import 'apis/matches_api.dart';
import 'apis/messages_api.dart';
import 'apis/profile_api.dart';
import 'apis/queue_api.dart';
import 'apis/safety_api.dart';
import 'apis/swipe_api.dart';

class ReverseMatchApiClient {
  ReverseMatchApiClient({required Dio dio})
      : auth = AuthApi(dio),
        profile = ProfileApi(dio),
        swipe = SwipeApi(dio),
        queue = QueueApi(dio),
        matches = MatchesApi(dio),
        messages = MessagesApi(dio),
        boost = BoostApi(dio),
        safety = SafetyApi(dio),
        account = AccountApi(dio),
        config = ConfigApi(dio),
        idealMatch = IdealMatchApi(dio);

  final AuthApi auth;
  final ProfileApi profile;
  final SwipeApi swipe;
  final QueueApi queue;
  final MatchesApi matches;
  final MessagesApi messages;
  final BoostApi boost;
  final SafetyApi safety;
  final AccountApi account;
  final ConfigApi config;
  final IdealMatchApi idealMatch;
}
