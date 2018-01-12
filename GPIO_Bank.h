class GPIO_Bank
{
    int GPIO_file;

public:
    GPIO_Bank(unsigned char address);
    ~GPIO_Bank();
    void Set_Configuration(unsigned char selection);
    void Set_Outputs(unsigned char selection);
    unsigned char Read_Inputs(void);
    void Set_Polarity(unsigned char selection);
};
