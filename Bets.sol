pragma solidity ^0.8.0;

contract ApostasBlock{

    struct dataSorteio {
        uint256 horaInicial;
        uint256 minutoInicial;
        uint256 horaFinal;
        uint256 minutoFinal;
    }

    struct dataAposta{
        uint256 horaAtual;
        uint256 minutoAtual;
    }

    enum estadoAposta {EM_ANDAMENTO,PERDEU,GANHOU}

    struct Aposta {
        address usuario;
        uint256 valorApostado;
        uint256 idAposta; //idDoSorteio
        uint[] valores;
        estadoAposta estado;
        dataAposta data;
    }

    struct Sorteio {
        dataSorteio data;
        uint256 quantidadeSorteados; // Números Sorteados
        uint256 porcentagemDoValor;
        uint256 idSorteio;
        bool aberto;
        string infor;
        uint256[] apostas;
        uint256[] valoresSorteados;
        uint256 Acumulado;
        uint256 Distributed;
        uint256 Prize;
    }

    Sorteio[] public listaSorteios;
    uint qnt = 0;
    // (ID)Sorteio --> (ID)Aposta --> Apostas
    mapping(uint256 => mapping(uint256 => Aposta)) public apostas;
    address public admin; // Admin primeira conta que executar o contato.

    event SorteioInfo(uint256 Acumulado,uint256 Distributed,uint256 Prize);
    event Sorteados(uint256[] sorteados);
    event Acumulativo(uint256 Acumulativo);
    event Ganhadores(uint256 idDoSorteio, address usuario, uint256[] sorteados);
    event apos(uint256[] valoresAtuais,uint256[] valoresApostados);
    constructor() {
        admin = msg.sender;
    }

    // Modifiers faz uma veriçação antes das funções serem executadas.
    // Para verificar se é o administrador que está fazendo algo.
    modifier apenasAdmin() {
        require(msg.sender == admin, "Somente o Administrador pode realizar!");
        _;
    }

    

    function pegarHoraMinutoAtual() public view returns (uint[2] memory) {
        uint timestamp = block.timestamp;
        uint offset = 3;
        uint horaAtual = ((timestamp - offset * 3600) / 3600) % 24;
        uint minutoAtual = (timestamp / 60) % 60;
        return [horaAtual, minutoAtual];
    }

    function sortearNumero() public view returns (uint256) {
        uint256 numero = uint(keccak256(abi.encodePacked(blockhash(block.number-1),block.timestamp)));
        return (numero % 2)+1;
    }

    function bolha(uint256[] memory valoresApostas) public pure returns (uint256[] memory){
        uint256 tamanho =  valoresApostas.length;
        uint256 aux;
        for (uint256 i=0;i<tamanho-1;i++) {
            for (uint256 j=0;j<tamanho-i-1;j++) {
                if (valoresApostas[j]>valoresApostas[j+1]){
                    aux = valoresApostas[j];
                    valoresApostas[j] = valoresApostas[j+1];
                    valoresApostas[j+1] = aux;
                }
            }
        }
        return valoresApostas;
    }

    function comparaApostas(uint256[] memory v1, uint256[] memory v2) public pure returns (bool) {
        if (v1.length != v2.length) {
            return false;
        }
        for (uint i = 0; i < v1.length; i++) {
            if (v1[i] != v2[i]) {
                return false;
            }
        }
        return true;
    }

    function criandoSorteio(uint256 _horaInicial, uint256 _minutoInicial, 
                            uint256 _horaFinal, uint256 _minutoFinal, uint256 _quantidadeSorteados,
                            uint256 _porcentagemDoValor,
                            string memory _infor) public apenasAdmin {
        
        require(_horaInicial < 24 && _minutoInicial < 60, "Hora ou Minuto incorretos!");
        require(_horaFinal < 24 && _minutoFinal < 60, "Hora ou Minuto incorretos!");
        require((_horaInicial < _horaFinal || (_horaInicial == _horaFinal && _minutoInicial <= _minutoFinal)), "O tempo incial deve ser anterior ao tempo final!");
        /* Se passar é pq está tudo OK! */
        dataSorteio memory dataLimite;
        dataLimite.horaInicial = _horaInicial;
        dataLimite.minutoInicial = _minutoInicial;
        dataLimite.horaFinal = _horaFinal;
        dataLimite.minutoFinal = _minutoFinal;
        listaSorteios.push(Sorteio(dataLimite,_quantidadeSorteados,_porcentagemDoValor,qnt,true,_infor,new uint256[](0),new uint256[](0),0,0,0));
        qnt+=1;
    }

    function realizandoAposta(uint256 _idDoSorteio, uint256[] memory _numerosApostados) public payable{
        require(_idDoSorteio < qnt, "ID do Sorteio incorreto!");        
        Sorteio storage sorteioAtual = listaSorteios[_idDoSorteio];
        // Verificando se os valores apostados são do mesma quantidade dos números permitidos.
        require(_numerosApostados.length == sorteioAtual.quantidadeSorteados,"Quantidade de valores diferente do sorteio!");
        require(msg.value > 0, "A quantia deve ser maior que 0.");
        uint[2] memory tempoAtual = pegarHoraMinutoAtual();
        uint256 horaAtual = tempoAtual[0];
        uint256 minutoAtual = tempoAtual[1];
        require((horaAtual > sorteioAtual.data.horaInicial || (horaAtual == sorteioAtual.data.horaInicial && minutoAtual >= sorteioAtual.data.minutoInicial)), "Nao eh permitido realizar sorteio!");
        require((horaAtual < sorteioAtual.data.horaFinal || (horaAtual == sorteioAtual.data.horaFinal && minutoAtual < sorteioAtual.data.minutoFinal)), "Nao eh permitido realizar sorteio!");
        // Se passou quer dizer que está apto a realizar a aposta!
        Aposta storage aposta = apostas[_idDoSorteio][sorteioAtual.apostas.length];
        uint256[] memory ordenados = bolha(_numerosApostados);
        bool valida = false;

        for (uint256 i=0;i<sorteioAtual.apostas.length;i++){
            Aposta memory apostaX = apostas[_idDoSorteio][i];
            if (apostaX.usuario == msg.sender){
                uint256[] memory valoresX = apostaX.valores;
                valida = comparaApostas(ordenados,valoresX);
                emit apos(ordenados,valoresX);
            }
        }
        require(!valida,"Voce ja realizou essa aposta!");
        aposta.usuario = msg.sender;
        aposta.valorApostado = msg.value;
        aposta.idAposta = _idDoSorteio;
        aposta.valores = ordenados;
        aposta.estado = estadoAposta.EM_ANDAMENTO;
        sorteioAtual.apostas.push(sorteioAtual.apostas.length);
    }

    function realizaSorteio(uint256 _idDoSorteio) public payable apenasAdmin {
        require(_idDoSorteio < qnt, "Esse ID eh incorreto!");
        Sorteio storage sorteioAtual = listaSorteios[_idDoSorteio];
        // require(sorteioAtual.aberto, "Sorteio nao esta em andamento!!!");
        // uint[2] memory tempoAtual = pegarHoraMinutoAtual();
        // uint256 horaAtual = tempoAtual[0];
        // uint256 minutoAtual = tempoAtual[1];
        // require((horaAtual > sorteioAtual.data.horaFinal || (horaAtual == sorteioAtual.data.horaFinal && minutoAtual >= sorteioAtual.data.minutoFinal)), "O sorteio esta em andamento!");
        sorteioAtual.aberto = false;
        uint256 acumulativo = 0;
        uint256[] memory sorteados;
        sorteados = new uint256[](sorteioAtual.quantidadeSorteados);
        for (uint256 j = 0; j < sorteioAtual.quantidadeSorteados; j++){
            uint256 valor = sortearNumero();
            sorteados[j] = valor;
        }
        emit Sorteados(sorteados);
        
        // uint256[] storage todasApostas = sorteioAtual.apostas;
        for (uint256 i = 0; i < sorteioAtual.apostas.length; i++){
            Aposta storage apostaAtual = apostas[_idDoSorteio][i];
            acumulativo += apostaAtual.valorApostado;
        }
        emit Acumulativo(acumulativo);
        
        uint256[] memory sorteadosOrdenados = bolha(sorteados);
        sorteioAtual.valoresSorteados = sorteadosOrdenados;
        sorteioAtual.Acumulado = acumulativo;
        
        // Definir quem Ganhou ou Não!
        
        uint256 ganhadores = 0;
        for (uint256 k = 0; k < sorteioAtual.apostas.length; k++){
            Aposta storage apostaAtual = apostas[_idDoSorteio][k];
            if(comparaApostas(sorteadosOrdenados,apostaAtual.valores)){
                apostaAtual.estado = estadoAposta.GANHOU;
                ganhadores+=1;
                emit Ganhadores(_idDoSorteio,apostaAtual.usuario,apostaAtual.valores);
            }
            else{
                apostaAtual.estado = estadoAposta.PERDEU;
            }
        }
        
        // Cálculo de porcentagem do valor.
        /* uint256 porcentagem = (sorteioAtual.porcentagemDoValor).div(100); */
        uint256 porcentagem2 = (sorteioAtual.Acumulado*sorteioAtual.porcentagemDoValor)/100;
        sorteioAtual.Distributed = porcentagem2;


        uint256 paraCadaGanhador;
        if(ganhadores!=0){ paraCadaGanhador = porcentagem2/ganhadores;}
        else{ paraCadaGanhador = 0;}
        sorteioAtual.Prize = paraCadaGanhador;   
        emit SorteioInfo(sorteioAtual.Acumulado,sorteioAtual.Distributed,sorteioAtual.Prize);
        for (uint256 l = 0; l < sorteioAtual.apostas.length; l++){
            Aposta storage apostaAtual = apostas[_idDoSorteio][l];
            if(apostaAtual.estado == estadoAposta.GANHOU){
                emit Ganhadores(_idDoSorteio,apostaAtual.usuario,apostaAtual.valores);
            }
        }
        
        for (uint256 l = 0; l < sorteioAtual.apostas.length; l++){
            Aposta storage apostaAtual = apostas[_idDoSorteio][l];
            if(apostaAtual.estado == estadoAposta.GANHOU){
                bool transferSuccess = payable(apostaAtual.usuario).send(sorteioAtual.Prize);
            }
        }
        payable(msg.sender).transfer(acumulativo-sorteioAtual.Distributed);
    }

    function exibeInforSorteio(uint256 _idDoSorteio) public view returns(uint256[3] memory){
        require(_idDoSorteio < qnt, "Esse ID eh incorreto!");
        Sorteio memory sorteioAtual = listaSorteios[_idDoSorteio];
        return [sorteioAtual.apostas.length,sorteioAtual.Prize,sorteioAtual.Acumulado];
    }

}