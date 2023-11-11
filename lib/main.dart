import 'package:flutter/material.dart';
import 'package:gruene_auth_app/app/app.dart';
import 'package:gruene_auth_app/app/config/config.dart';
import 'package:gruene_auth_app/features/authenticator/domain/authenticator_factory.dart';
import 'package:gruene_auth_app/features/authenticator/models/authenticator_model.dart';
import 'package:gruene_auth_app/features/authenticator/models/tip_of_the_day_model.dart';
import 'package:keycloak_authenticator/keycloak_authenticator.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

void main() {
  var appConfig = AppConfig(
    environment: Environment.development,
    keycloakBaseUrl: 'http://192.168.2.196:8080',
    keycloakRealm: 'dev',
  );
  GetIt.I.registerSingleton<AppConfig>(appConfig);

  GetIt.I.registerFactory<AuthenticatorInterface>(AuthenticatorFactory.create);

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (context) => AuthenticatorModel(),
      ),
      ChangeNotifierProvider(
        create: (context) => TipOfTheDayModel(),
      ),
    ],
    child: const MyApp(),
  ));
}
