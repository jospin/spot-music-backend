## Criando uma estrutura para todos os componentes 
Todos os componentens estão inicializados e podem ser iniciados de analytics a playlist. Cada um tem o seu Dockerfile com a versão do python que deverá ser utilizada.

### Docker Compose

O Docker composer faz a integração dos componentes em uma única rede. Veja que no docker composer está chamando a imagem pelo nome do componente. Isso só é possível, pois dentro de cada componente tem um Dockerfile que precisa ser rodado para gerar as imaagens individuais e nomeadas atraves do seguinte comando rodado dentro da pasta do componente que deseja criar a imagem.

```bash
docker build -t nome-do-componente .
```

#### Rodar a imnagem geral

Para rodar todos os serviços (apos realizar o docker build de todos os componentes), basta entrar na pasta principal e subir o composer atraves do seguinte comando

```bash
docker-compose up
```

