# Déployer une application Django sur AWS en utilisant ECS, ECR et terraform 

![AWS](https://imgur.com/wLMcRHS.jpg)

**Cet article déploiera une application basée sur Django sur AWS en utilisant ECS (Elastic Container Service) et ECR (Elastic Container Registry). Nous commençons par créer l’image docker de notre application et la pousser vers ECR. Ensuite, nous créons l’instance et déployons l’application sur AWS en utilisant ECS. Enfin, nous nous assurons que l’application fonctionne correctement en utilisant le serveur web intégré de Django.**

## Prérequis

* Django
* Connaissances de base en Docker
* Compte AWS

## Framework Web Django 

***Django est un framework web Python de haut niveau qui encourage un développement rapide et une conception propre et pragmatique. Il est gratuit et open-source, dispose d’une communauté active et dynamique, d’une excellente documentation, ainsi que de nombreuses options de support gratuites et payantes. Il utilise HTML/CSS/Javascript pour le frontend et Python pour le backend..***

## Qu’est-ce que Docker et les conteneurs ?

![Docker](https://imgur.com/raGErLx.png)

### Flux de travail Docker

**Docker est une plateforme logicielle ouverte. Il est utilisé pour développer, expédier et exécuter des applications. Docker virtualise le système d’exploitation de l’ordinateur sur lequel il est installé et fonctionne. Il permet d’emballer et d’exécuter une application dans un environnement faiblement isolé appelé conteneur. Un conteneur est une instance exécutable d’une image docker. Vous pouvez créer, démarrer, arrêter, déplacer ou supprimer un conteneur en utilisant l’API Docker ou la CLI. Vous pouvez connecter un conteneur à un ou plusieurs réseaux, lui attacher du stockage, ou même créer une nouvelle image docker basée sur son état actuel.**

## Qu’est-ce qu’AWS Elastic Container Registry ?

**Amazon Elastic Container Registry (Amazon ECR) est un service géré de registre d’images de conteneurs. Les clients peuvent utiliser la CLI Docker familière, ou leur client préféré, pour pousser, tirer et gérer des images. Amazon ECR fournit un registre sécurisé, évolutif et fiable pour vos images Docker.**

### Étapes ECR  

Voici la tâche dans laquelle nous créons le dépôt sur AWS en utilisant ECR où résidera l’image docker de notre application. Pour commencer la création d’un dépôt sur ECR, nous recherchons d’abord ECR dans la console AWS et suivons les étapes ci-dessous.

1. **Créer un fichier Docker** — Ajoutez le “Dockerfile” à l’application Django. Il contient la série de commandes nécessaires à la création de l’image docker.

2. **Bonstruire image Docker** —     tilisez la commande ci-dessous pour créer l’image docker nommée “django-app:version:1”.

```
docker build -t hello-world-django-app:version-1 
```

3. Vérifiez si l’image docker est créée ou non en utilisant la commande ci-dessous.

```
docker images | grep hello-world-django-app 
```

4. **Créer un dépôt sur AWS ECR** — Il est temps d’ouvrir la console AWS et de rechercher ECR. Ensuite, cliquez sur le bouton Créer un dépôt.

**YVous trouverez deux options pour la visibilité de votre dépôt, c’est-à-dire Privé et Public. L’accès au dépôt privé est géré par IAM et les permissions des politiques de dépôt. Une fois que vous cliquez sur le bouton créer un dépôt, vous devez donner un nom à votre dépôt. Si vous activez l’option “scan on push”, cela aide à identifier les vulnérabilités logicielles dans vos images de conteneurs.**

5. **Pousser l’image docker créée de l’application Django à l’étape 2 vers AWS ECR** —

a) Authentifiez votre client Docker auprès du registre Amazon ECR. Des tokens d’authentification doivent être obtenus pour chaque registre utilisé, et ces tokens sont valides pendant 12 heures. La façon la plus simple de faire cela est d’obtenir la clé AWS AWS_ACCESS_KEY_ID et le secret AWS_SECRET_ACCESS_KEY. Puis exécutez la commande ci-dessous.
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. Then run the below command.

```
export AWS_ACCESS_KEY_ID=******
export AWS_SECRET_ACCESS_KEY=******
```

Après avoir exporté les variables AWS_ACCESS_KEY_ID et AWS_SECRET_ACCESS_KEY, connectez-vous au compte AWS en utilisant la commande ci-dessous.

```
aws ecr get-login-password --region region | docker login --username AWS --password-stdin aws_account_id.dkr.ecr.region.amazonaws.com
```

b) Identifiez l’image à pousser en utilisant la commande docker images :

```
REPOSITORY                                                                TAG                     IMAGE ID          CREATED            SIZE
django-app version-1    480903dd8        2 days ago          549MB
```

c) Étiquetez votre image avec le registre Amazon ECR, le dépôt, et la combinaison optionnelle du nom de tag d’image à utiliser. Le format du registre est aws_account_id.dkr.ecr.region.amazonaws.com. Le nom du dépôt doit correspondre au dépôt que vous avez créé pour votre image.

L’exemple suivant étiquette une image avec l’ID 480903dd8 en tant que aws_account_id.dkr.ecr.region.amazonaws.com/hello-world-django-app.

```
docker tag 480903dd8 aws_account_id.dkr.ecr.region.amazonaws.com/hello-world-django-app
```

d) Poussez l’image docker en utilisant la commande docker push :

```
docker push aws_account_id.dkr.ecr.region.amazonaws.com/hello-world-django-app
```

## Qu’est-ce que AWS Elastic Container Service ?

**Amazon Elastic Container Service (ECS) est un service de gestion de conteneurs hautement évolutif et performant qui supporte les conteneurs Docker et vous permet d’exécuter facilement des applications sur un cluster géré d’instances Amazon EC2. Avec Amazon ECS, nous pouvons installer, exploiter et scaler notre application grâce à sa propre infrastructure de gestion de cluster. En utilisant quelques appels API simples, nous pouvons lancer et arrêter nos applications Docker, interroger les logs de notre cluster, et accéder à de nombreuses fonctionnalités familières comme les groupes de sécurité, Elastic Load Balancer, les volumes EBS, et les rôles IAM. Nous pouvons utiliser Amazon ECS pour planifier le placement des conteneurs à travers notre cluster selon nos besoins en ressources et exigences de disponibilité. Nous pouvons également intégrer notre propre ordonnanceur ou des ordonnanceurs tiers pour répondre aux exigences métier ou spécifiques à l’application.**

### Étapes ECS

Il est maintenant temps de lancer notre première instance EC2 en utilisant AWS ECS. Pour commencer, recherchons d’abord ECS dans la console AWS et suivons les étapes ci-dessous.

1. **Créer un cluster** — a console de création de cluster offre un moyen simple de créer les ressources et vous permet de personnaliser plusieurs options communes de configuration du cluster. N’oubliez pas de sélectionner la région où utiliser votre cluster depuis le panneau de navigation.

2. **Lancer une instance EC2** —  À cette étape, nous configurons notre cluster. Certaines de ces configurations concernent le réseau, CloudWatch Container Insights, et les groupes d’auto-scaling. C’est l’étape la plus cruciale lors de la création de votre cluster car certaines configurations ne peuvent pas être modifiées après la création.

3. **Créer un service qui exécute la définition de tâche** — Un service définit comment exécuter votre service ECS. Certains des paramètres importants spécifiés dans la définition du service sont le cluster, le type de lancement, et la définition de tâche.

4. **Créer une tâche** — Pour exécuter des conteneurs Docker sur AWS ECR, nous devons d’abord créer la définition de tâche. Nous pouvons configurer plusieurs conteneurs et le stockage des données dans une seule définition de tâche. Lors de la création de la définition de tâche, nous spécifions quel ECR utiliser pour quel conteneur ainsi que les mappages de ports.

5. **Exécuter l’instance en déclenchant la tâche créée** — Après avoir réalisé avec succès toutes les étapes ci-dessus, nous sommes maintenant à l’étape de déclencher notre tâche créée en accédant au cluster. Après avoir lancé notre tâche, nous pouvons vérifier dans la console EC2 si notre instance créée est en fonctionnement ou non.

### Automatisaton 
Pour automatiser et simplifier le déploiement, vous pouvez également utiliser Terraform. Il suffit d’exécuter les fichiers de configuration Terraform dans votre terminal en vous assurant d’être connecté à votre compte AWS. Par exemple, lancez terraform init pour initialiser le projet, puis terraform apply pour appliquer la configuration et créer toutes les ressources nécessaires sur AWS.

## Félicitations! 🙂

**Nous avons déployé avec succès notre application Django sur le cloud AWS en utilisant ECS et ECR.**

#### Auteur [Mamiche A](https://github.com/Mamiche)
