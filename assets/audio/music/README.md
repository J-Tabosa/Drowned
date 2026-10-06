# Trilha original de Drowned

Composição original e síntese procedural para este projeto. Não utiliza
gravações, samples ou faixas de terceiros.

As três faixas são camadas sincronizadas a 72 BPM, em ré menor, com 16 compassos
e duração de 53,33 s. A base é lenta e calma; os tambores acompanham as ondas;
a guitarra entra na sala do chefe. Transições e volume são controlados por
`scripts/autoload/music_director.gd`.

O gerador reproduzível é `tools/compose_soundtrack.py` (Python + NumPy).
Mantenha os três WAVs com o mesmo comprimento e importação PCM de 16 bits.
Veja `docs/gameplay_audio.md` para controles, comportamento e testes.
