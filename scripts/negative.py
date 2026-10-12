"""Isolated RTL mutations must fail a protocol/data check, never the watchdog."""
import pathlib,subprocess,tempfile
root=pathlib.Path(__file__).resolve().parents[1]
source=(root/'rtl/axis_cdc.sv').read_text()
mutations=[
 ('m_rst_n && !empty','m_rst_n && !empty && m_axis_tready','buffered output must assert valid'),
 ('if(wstrb[lane])','if(1\'b1)','register'),
 ('if(aw_pending && w_pending && !s_axil_bvalid)','if(aw_pending && !s_axil_bvalid)','register'),
]
for old,new,expected in mutations:
    assert old in source
    with tempfile.TemporaryDirectory() as tmp:
        p=pathlib.Path(tmp)
        (p/'axis_cdc.sv').write_text(source.replace(old,new))
        subprocess.run(['iverilog','-g2012','-s','tb_axis_cdc','-o',str(p/'sim'),str(root/'rtl/async_fifo.sv'),str(p/'axis_cdc.sv'),str(root/'tb/tb_axis_cdc.sv')],check=True)
        result=subprocess.run(['vvp',str(p/'sim'),'+SEED=1'],capture_output=True,text=True)
        print('MUTATION:',old,'->',new);print(result.stdout)
        assert result.returncode!=0 and expected in result.stdout and 'watchdog' not in result.stdout, 'mutation escaped or hung'
        print('PASS detected mutation; exit',result.returncode)
