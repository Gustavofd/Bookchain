// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title Bookchain
 * @dev Manage a virtual distributed book store.
 */
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

    // Mapeamento entre o endereço do livro e as informacoes de aluguel
    mapping(address => Rental[]) public rentals;

    // Mapeamento entre o endereco do livro e os dados do livro
    mapping(address => BookData) public bookData;

    // Mapeamento entre o endereco do leitor e o livro alugado
    mapping(address => address) public rentedBooks;

    // Array para armazenar os endereços dos livros publicados
    address[] public publishedBooks;

    // Mapeamento entre o endereco do leitor e seu saldo de Bookcoins
    mapping(address => uint256) public balances;

    // Evento emitido quando um livro eh publicado
    event BookPublished(address indexed book, string title, string content, uint256 rentalPrice);

    // Evento emitido quando um livro eh alugado
    event BookRented(address indexed book, address indexed renter, uint256 startDate, uint256 endDate);

    // Evento emitido quando um pagamento de aluguel eh realizado em Bookcoins
    event RentPayment(address indexed book, address indexed renter, address indexed author, uint256 amount);

    // Evento emitido quando o saldo do autor eh consultado
    event BalanceChecked(address indexed author, uint256 balance);

    // Evento emitido quando o histórico de alugueis eh consultado
    event RentalHistoryChecked(address indexed renter, address indexed book, uint256 startDate, uint256 endDate);

    // Evento emitido quando a lista de livros disponiveis eh consultada
    event AvailableBooksChecked(address indexed renter, address[] books);

    // Func para publicar um livro
    function publishBook(address _book, string memory _title, string memory _content, uint256 _rentalPrice) external {
        require(!bookData[_book].isPublished, "Livro ja foi publicado");

        bookData[_book] = BookData({
            title: _title,
            content: _content,
            rentalPrice: _rentalPrice,
            isPublished: true
        });

        // Add the book to the publishedBooks array
        publishedBooks.push(_book);

        emit BookPublished(_book, _title, _content, _rentalPrice);
    }

    // Func para alugar um livro
    function rentBook(address _book, uint256 _days) external {
        require(bookData[_book].isPublished, "Livro nao encontrado");
        require(balances[msg.sender] >= bookData[_book].rentalPrice, "Saldo de Bookcoins insuficiente");
        require(rentedBooks[msg.sender] != _book, "Livro ja alugado pelo mesmo leitor");

        Rental[] storage bookRentals = rentals[_book];
        bookRentals.push(Rental(msg.sender, block.timestamp, block.timestamp + (_days * 1 days)));

        rentedBooks[msg.sender] = _book;

        // Calculo dos valores a serem pagos
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

    // Func para o autor consultar seu saldo de Bookcoins
    function checkBalance() external {
        address author = address(this);
        emit BalanceChecked(author, balances[author]);
    }

    // Func para o leitor consultar seu historico de aluguel
    function checkRentalHistory() external {
        Rental[] storage rentalHistory = rentals[rentedBooks[msg.sender]];
        for (uint256 i = 0; i < rentalHistory.length; i++) {
            emit RentalHistoryChecked(msg.sender, rentedBooks[msg.sender], rentalHistory[i].startDate, rentalHistory[i].endDate);
        }
    }

    // Func para verificar se o leitor tem permissao para ler o livro
    function canReadBook(address _reader, address _book) public view returns (bool) {
        Rental[] storage rentalHistory = rentals[_book];
        for (uint256 i = 0; i < rentalHistory.length; i++) {
            if (rentalHistory[i].renter == _reader) {
                return true;
            }
        }
        return false;
    }

    // Func para obter os livros disponiveis para aluguel
    function getAvailableBooks() external view returns (address[] memory) {
        uint256 availableBooksCount = 0;
        address[] memory availableBooks = new address[](publishedBooks.length);

        for (uint256 i = 0; i < publishedBooks.length; i++) {
            address bookAddress = publishedBooks[i];
            if (bookData[bookAddress].isPublished) {
                availableBooks[availableBooksCount] = bookAddress;
                availableBooksCount++;
            }
        }

        // Resize the array to remove empty slots
        assembly {
            mstore(availableBooks, availableBooksCount)
        }

        return availableBooks;
    }

    // Func para obter os livros disponiveis para um usuario
    function getAvailableBooksForUser() external view returns (address[] memory) {
        uint256 availableBooksCount = 0;
        address[] memory availableBooks = new address[](publishedBooks.length);

        for (uint256 i = 0; i < publishedBooks.length; i++) {
            address book = publishedBooks[i];

            // Verificar se o livro está publicado
            if (bookData[book].isPublished) {
                availableBooks[availableBooksCount] = book;
                availableBooksCount++;
            } else if (rentedBooks[book] == msg.sender) {
                // Verificar se o usuário alugou o livro e o aluguel ainda não expirou
                Rental[] storage bookRentals = rentals[book];
                for (uint256 j = 0; j < bookRentals.length; j++) {
                    if (bookRentals[j].renter == msg.sender && block.timestamp < bookRentals[j].endDate) {
                        // O usuário alugou o livro e o aluguel ainda está ativo
                        availableBooks[availableBooksCount] = book;
                        availableBooksCount++;
                        break;
                    }
                }
            }
        }

        // Resize the array to remove empty slots
        assembly {
            mstore(availableBooks, availableBooksCount)
        }

        return availableBooks;
    }

}
