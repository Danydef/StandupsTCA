# App de demostración donde mejoramos considerablemete la app de Apple Scrumdinger, en esta ocasión usando la arquitectura TCA #

* En este primer commit comenzamos a reescribir la app Scrumdiger, llamada StandupsTCA pero en esta ocasión lo hacemos usando [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)

* Segundo commit añadimos la conexión entre el dominio primario y el secundario.

* Tercer commit añadimos la pantalla de detalle del Standup, donde podemos includo editarlo, se ha realizado algún tests no exaustivo, pero podemos mejorarlo, para la proxima navegaremos desde la pantalla principal hasta el detalle.

* Cuarto commit, en esta ocasión añadimos varias cosas nuevas entre otras cosas, dos structs nuevas que actuan como concentrador de nuestras vistas, `AppFeature` `AppView`, también se ha añadido la capacidad de que dominios secundarios o hijos puedan comunicarse con su dominio principal o padre. Lógicamente y como siempre se han añadido algunos test.

