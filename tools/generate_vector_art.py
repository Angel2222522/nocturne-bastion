"""Original resolution-independent layered art for PULSE; no third-party assets."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1] / 'assets/vector'
ROOT.mkdir(parents=True, exist_ok=True)
def save(name, body, box='-40 -40 80 80'):
    ROOT.joinpath(name+'.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="160" height="160" viewBox="{box}">{body}</svg>')
save('foundation', '''<ellipse cx="2" cy="10" rx="30" ry="21" fill="#695755" opacity=".19"/>
<path d="M-27-12-12-25 15-25 28-10 28 15 12 28-14 28-28 13Z" fill="#a98d7e"/>
<path d="M-27-17-12-30 15-30 28-15 28 9 12 22-14 22-28 7Z" fill="#f6e9ca" stroke="#a48c7a" stroke-width="2"/>
<path d="M-20-13-9-23 12-23 21-12 21 5 10 15-11 15-21 4Z" fill="#c5b5a0"/>
<path d="M-18-12-8-20 11-20 18-11 18 3 9 12-10 12-18 3Z" fill="#ddd0b5"/>
<path d="M-26-17-12-29 15-29 27-15M-26-17V7L-14 20" fill="none" stroke="#fff8df" stroke-width="3"/>
<path d="M-6-7H6V-3H2V1H-2V-3H-6Z" fill="#927c74"/>
<path d="M-18 11-13 16M16 9 12 14M-16-18-12-22M15-18 11-22" stroke="#ad927c" stroke-width="3"/>''')
save('tower_base', '''<ellipse cx="2" cy="12" rx="29" ry="21" fill="#59415c" opacity=".25"/>
<path d="M-27-10-12-25H14L28-10V13L12 27H-13L-28 12Z" fill="#66536e"/>
<path d="M-27-16-12-30H14L28-16V7L12 20H-13L-28 6Z" fill="#fff4d8" stroke="#9f8d93" stroke-width="2"/>
<path d="M-18-13-8-22H10L20-12V2L9 12H-8L-19 2Z" fill="#867193"/>
<path d="M-16-14-6-22 11-20 20-10 16 2 5 10-10 7-18-3Z" fill="#554460"/>
<path d="M-23-15-12-26H13L24-15M-25 5-13 16" fill="none" stroke="#fffdf0" stroke-width="3"/>
<path d="M-7-14 3-19 12-12 8-3-3 0-11-6Z" fill="#c488ef"/>
<path d="M-7-14 3-19 0-7-11-6Z" fill="#f2d7ff"/>
<path d="M-25-4-19-6M21-3 27-1M-5 15V21" stroke="#c69e52" stroke-width="4"/>''')
save('turret', '''<path d="M-9-13H26L31-8 26-3H-9Z" fill="#4e3c5d" stroke="#34233f" stroke-width="2"/>
<path d="M-9 3H26L31 8 26 13H-9Z" fill="#4e3c5d" stroke="#34233f" stroke-width="2"/>
<path d="M-2-13H22V-8H-2ZM-2 3H22V8H-2Z" fill="#ad8ac1"/>
<path d="M9-15H15V-2H9ZM9 2H15V15H9Z" fill="#e3bd7b"/>
<path d="M23-15H31V-1H23ZM23 1H31V15H23Z" fill="#f9eccd" stroke="#a78a84" stroke-width="2"/>
<path d="M28-11H32V-5H28ZM28 5H32V11H28Z" fill="#362a42"/>
<path d="M-20-14-5-20 7-11 8 9-4 19-20 12-25-1Z" fill="#f7edd4" stroke="#867184" stroke-width="2"/>
<path d="M-20-14-5-20 7-11-6-6-22-4Z" fill="#fff9e7"/>
<path d="M-6-6 7-11 8 9-4 19-6 5Z" fill="#c5b4b8"/>
<path d="M-14-11-6-14 0-7-1 3-9 8-17 2Z" fill="#9b5bd2"/>
<path d="M-14-11-6-14-8-2-17 2Z" fill="#e4b8ff"/>
<path d="M-18 7-9 11M-20-1-15-4" stroke="#a7844b" stroke-width="3"/>''')
save('mite_body', '''<path d="M-20-5-10-15 8-13 23-3 20 8 5 17-13 12-23 3Z" fill="#572e43" stroke="#392537" stroke-width="2"/>
<path d="M-20-5-10-15 0-10-3 2-18 3Z" fill="#bd6656"/>
<path d="M0-10 8-13 20-4 11 3-3 2Z" fill="#e17a5d"/>
<path d="M-18 3-3 2 1 14-13 12Z" fill="#894455"/>
<path d="M-3 2 11 3 20 8 5 17 1 14Z" fill="#9f4b4b"/>
<path d="M-4-10-3 2 2 13M-17 2-3 2 12 4" fill="none" stroke="#ffb35f" stroke-width="2"/>
<path d="M15-7 25-5 29 0 24 7 15 6 11 0Z" fill="#49304a"/>
<path d="M20-3 26-1 24 3 18 2Z" fill="#fff0ae"/>
<path d="M-13-11-6-8M3-8 10-7" stroke="#f8ba87" stroke-width="2"/>''')
save('core', '''<ellipse cy="22" rx="29" ry="14" fill="#4c3665" opacity=".25"/>
<path d="M-28 9-14-2H14L28 9V23L13 33H-14L-28 22Z" fill="#9e879e"/>
<path d="M-28 9-14-2H14L28 9 13 20H-14Z" fill="#fff2cf" stroke="#ac9294" stroke-width="2"/>
<path d="M-15 5-6-5 7-5 16 5 7 14H-7Z" fill="#6b447a"/>
<path d="M0-35 16-15 12 7 0 15-13 4-17-15Z" fill="#ac64df" stroke="#663d8a" stroke-width="2"/>
<path d="M0-35-2-7-13 4-17-15Z" fill="#ebbeff"/>
<path d="M0-35 16-15-2-7Z" fill="#f9e8ff"/>
<path d="M-2-7 16-15 12 7 0 15Z" fill="#8d4cc6"/>
<path d="M-2-7 0 15-13 4Z" fill="#c790f4"/>''')
save('portal', '''<ellipse cy="18" rx="29" ry="19" fill="#785766" opacity=".25"/>
<path d="M-29 15-23-20-11-33 12-33 26-18 30 15 20 23H-20Z" fill="#b58d7b"/>
<path d="M-25 12-20-17-9-29 10-29 21-16 26 12 17 18H-17Z" fill="#f5dfbb"/>
<path d="M-17 10-13-14-6-22H6L15-13 18 10 11 14H-10Z" fill="#60436d"/>
<path d="M-11 8-8-11 0-19 9-10 12 8Z" fill="#b376d9"/>
<path d="M-3-14 4-8-2 5 6 9H-7Z" fill="#efc5ff"/>
<path d="M-25 12-20-17-9-29 10-29M-23 4-16 3M16-8 23-7" fill="none" stroke="#fff4db" stroke-width="3"/>''')
