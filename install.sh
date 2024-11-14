#Минимально соместимые версии программ
DOCKER_MIN_VER="19.03.0"
DOCKER_COMPOSE_MIN_VER="1.27.1"
UNZIP_MIN_VER="1.0.0"

#Тестовый массив для сравнения  
PLANR_STRUCTURE=(images planr)

#Объявляем переменные
FILE_PATH=""
WORK_DIR=""
PASSWORD="planr"
SET_FILE=./.set

#Функция, вывод справки по флагам
function help() {
  echo ""  
  echo -e "    \033[1mФлаги:\033[0m"  
  echo "    -f    Директория в которой находится архив с дистрибутивом или установочные файлы"
  echo "    -w    Директория развёртывания"
  echo "    -h    Справка"
}

#Функция, которая проверяет, переданы ли в скрипт значения переменных.
check_var() {
  declare var_name=$1
  # Получение значения переменной по её имени
  declare var_value=${!var_name}  

  if [[ -z "$var_value" ]]; then
    echo "Ошибка! Не присвоено значение переменной $var_name в файле $SET_FILE или аргумент у флага"
    exit 1
  else
    echo "$var_value"
  fi
}

#Функция для проверки совместимости и наличия программ в системе
function check_compatible {
  declare compatible_program=$1
  declare current_program=$2

  #Символ подстановки параметров // заменяет каждый символ . в переменной compatible_program
  #на пробел. Далее, значение переменной compatible_program присваиваются массиву compatible_prog_array
  compatible_prog_array=(${compatible_program//./ })

  $current_program -v > /dev/null
  if [ $? -eq 0 ]; then
    #Вывод команды current_program -v присваивается переменной RESULT
    RESULT=$($current_program -v)
    #Регулярное выражение. Оператор условной проверки =~ ищет в RESULT совпадения
    #из условия. BASH_REMATCH массив, который содержит совпадения из регулярного
    #выражения. 
    if [[ $RESULT =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
      echo "Версия $current_program: ${BASH_REMATCH[0]}"
    else
      echo "Не найдено совпадений из условия"
      exit 1
    fi
  else
    echo "Ошибка! $current_program не установлен в системе"
    exit 1
  fi    

  #Символ подстановки параметров // заменяет каждый символ . в массиве BASH_REMATCH
  #на пробел. Далее, значения массива BASH_REMATCH присваиваются массиву current_prog_array
  current_prog_array=(${BASH_REMATCH[0]//./ })

  if (( ${current_prog_array[0]} > ${compatible_prog_array[0]} )); then
    echo "Обнаружена совместимая версия $current_program ${BASH_REMATCH[0]}"
  elif (( ${current_prog_array[0]} == ${compatible_prog_array[0]} && ${current_prog_array[1]} >= ${compatible_prog_array[1]} )); then
    echo "Обнаружена совместимая версия $current_program ${BASH_REMATCH[0]}"
  else
    echo "Обнаружена несовместимая версия $current_program ${BASH_REMATCH[0]}"
    exit 1
  fi
}

#Проверка наличия в системе Docke,Docker-Compose,Unzip
check_compatible $DOCKER_MIN_VER docker
check_compatible $DOCKER_COMPOSE_MIN_VER docker-compose
check_compatible $UNZIP_MIN_VER unzip

#Функция, которая создаёт директорию развёртывания
function create_install_dir() {   
  #Проверка наличия архива с дистрибутивом или папки
  # c распакованным дистрибутивом
  if [ -e $FILE_PATH ]; then
    #Проверка,что директория WORK_DIR существует
    if [ -d $WORK_DIR ]; then
      #создаём каталоги для развёртывания
      mkdir -p $WORK_DIR/dppm/{distr,postgres_dump}
      #проверка создания каталога развёртывания
      if [ $? -eq 0 ]; then
        echo "Каталог развёртывания создан"
      else
        echo "Ошибка! Не удалось создать каталог развёртывания"
        exit 1
      fi    
    else
      echo "Ошибка! Директория развёртывания не существует"
      exit 1
    fi
  else
    echo "Ошибка! Архив с дистрибутивом или установочные файлы не найдены в указаной директории $FILE_PATH"
    exit 1
  fi  
}

#Передача параметров командной строки в скрипт с помощью флагов  
while getopts "f:w:h" Option
  do
    case $Option in
      f     )
             if [ ! -e "$OPTARG" ]; then
               echo "Ошибка! Архив с дистрибутивом или установочные файлы не найдены в указанной директории $OPTARG"
               exit 1
             fi
             FILE_PATH=$OPTARG;;  
      w     )
             if [ ! -d "$OPTARG" ]; then
               echo "Ошибка! $OPTARG не создан или это не директория"
               exit 1
             fi
             WORK_DIR=$OPTARG;;
      h     )
             help
             exit 1;;       
      *     )
             echo "Ошибка! Неизвестный флаг или флаг требует аргумента"
             help
             exit 1;;            
    esac
done  

#xargs преобразует строки из файла .set в формат переменных окружения для export
#export экспортирует значения переменных в intsall.sh
export $(grep -v '^#' $SET_FILE | xargs) > /dev/null
if [ $? -eq 0 ]; then
  echo "Переменные окружения экспортированы"
else
  echo "Ошибка! Не удалось экспортировать переменные окружения из файла .set"
  exit 1
fi

check_var "FILE_PATH"
check_var "WORK_DIR"

#Проверяем,является ли $FILE_PATH архивом
unzip -z $FILE_PATH > &> /dev/null
if [ $? -eq 0 ]; then
  #Создаём директорию развёртывания
  create_install_dir
  #Перемещаем дистрибутив
  mv $FILE_PATH $WORK_DIR/dppm/distr/
  if [ $? -eq 0 ]; then
    echo "Дистрибутив перемещён"
  else
    echo "Ошибка! Не удалось переместить дистрибутив"
    exit 1  
  fi
  #Регулярное выражение с переменной FILE_PATH. dirname возвращает путь  
  #к каталогу DIR, в котором находится файл. basename только имя файла FILE, без пути
  DIR="$(dirname "${FILE_PATH}")/" ; FILE="$(basename "${FILE_PATH}")"

  #Извлечение файлов из архива
  echo "Извлечение файлов из архива"
  unzip -P $PASSWORD $WORK_DIR/dppm/distr/$FILE -d $WORK_DIR/dppm/
  if [ $? -eq 0 ]; then
    echo "Извлечение файлов из архива, выполнено успешно"
  else
    echo "Ошибка! Не удалось извлечь файлы из архива"
    exit 1
  fi  
else
  #Присваиваем содержимое $FILE_PATH, массиву current_structure, исключая файлы
  #с расширением *.tgz
  current_structure=($(ls -I "*.tgz" $FILE_PATH))
  if [ "${PLANR_STRUCTURE[*]}" == "${current_structure[*]}" ]; then
    #Создаём директорию развёртывания
    create_install_dir
    #Перемещаем содержимое $FILE_PATH
    mv $FILE_PATH/* $WORK_DIR/dppm/
  else
    echo "Ошибка! Проверьте значение или содержимое FILE_PATH"
    exit 1 
  fi 
fi    

#Загруза образов
echo "Загрузка образов"
cd $WORK_DIR/dppm/images/
./load.sh
if [ $? -eq 0 ]; then
  echo "Образы успешно загружены"     
else
  echo "Ошибка! Образы не загружены"
  exit 1
fi 
