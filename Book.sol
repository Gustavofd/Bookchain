pragma solidity ^0.8.0;

contract Book {
    struct Rental {
        address renter;
        uint256 startDate;
        uint256 endDate;
    }

    struct BookData {
        string title;
        string content;
        uint256 rentalPrice;
        bool isPublished;
    }

    // Mapeamento entre o endereço do livro e as informações de aluguel
    mapping(address => Rental[]) public rentals;

    // Mapeamento entre o endereço do livro e os dados do livro
    mapping(address => BookData) public bookData;

    // Mapeamento entre o endereço do leitor e o livro alugado
    mapping(address => address) public rentedBooks;

    // Mapeamento entre o endereço do leitor e seu saldo de Bookcoins
    mapping(address => uint256) public balances;

    // Evento emitido quando um livro é publicado
    event BookPublished(address indexed book, string title, string content, uint256 rentalPrice);

    // Evento emitido quando um livro é alugado
    event BookRented(address indexed book, address indexed renter, uint256 startDate, uint256 endDate);

    // Evento emitido quando um pagamento de aluguel é realizado em Bookcoins
    event RentPayment(address indexed book, address indexed renter, address indexed author, uint256 amount);

    // Evento emitido quando o saldo do autor é consultado
    event BalanceChecked(address indexed author, uint256 balance);

    // Evento emitido quando o histórico de aluguéis é consultado
    event RentalHistoryChecked(address indexed renter, address indexed book, uint256 startDate, uint256 endDate);

    // Função para publicar um livro
    function publishBook(address _book, string memory _title, string memory _content, uint256 _rentalPrice) external {
        require(!bookData[_book].isPublished, "Livro já foi publicado");

        bookData[_book] = BookData({
            title: _title,
            content: _content,
            rentalPrice: _rentalPrice,
            isPublished: true
        });

        emit BookPublished(_book, _title, _content, _rentalPrice);
    }

    // Função para alugar um livro
    function rentBook(address _book, uint256 _days) external {
        require(bookData[_book].isPublished, "Livro não encontrado");
        require(balances[msg.sender] >= bookData[_book].rentalPrice, "Saldo de Bookcoins insuficiente");
        require(rentedBooks[msg.sender] != _book, "Livro já alugado pelo mesmo leitor");

        Rental[] storage bookRentals = rentals[_book];
        bookRentals.push(Rental(msg.sender, block.timestamp, block.timestamp + (_days * 1 days)));

        rentedBooks[msg.sender] = _book;

        // Cálculo dos valores a serem pagos
        uint256 rentalAmount = bookData[_book].rentalPrice;
        uint256 networkFee = rentalAmount * 3 / 100;
        uint256 authorAmount = rentalAmount - networkFee;

        // Transferir Bookcoins do leitor para o autor
        address author = address(this);
        balances[msg.sender] -= rentalAmount;
        balances[author] += authorAmount;
        balances[author] += networkFee;

        emit BookRented(_book, msg.sender, block.timestamp, block.timestamp + (_days * 1 days));
        emit RentPayment(_book, msg.sender, author, authorAmount);
        emit RentPayment(_book, msg.sender, address(this), networkFee);
    }

    // Função para o autor consultar seu saldo de Bookcoins
    function checkBalance() external {
        address author = address(this);
        emit BalanceChecked(author, balances[author]);
    }

    // Função para o leitor consultar seu histórico de aluguel
    function checkRentalHistory() external {
        Rental[] storage rentalHistory = rentals[rentedBooks[msg.sender]];
        for (uint256 i = 0; i < rentalHistory.length; i++) {
            emit RentalHistoryChecked(msg.sender, rentedBooks[msg.sender], rentalHistory[i].startDate, rentalHistory[i].endDate);
        }
    }
}
